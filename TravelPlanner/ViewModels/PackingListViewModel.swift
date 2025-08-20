import Foundation
import Combine
import SwiftUI
import CoreData
import Network

// Thêm struct để lưu cache với timestamp
struct CachedPackingList: Codable {
    let timestamp: Date
    let data: PackingList
}

class PackingListViewModel: ObservableObject {
    @Published var packingList: PackingList = PackingList(sharedItems: [], personalItems: [])
    @Published var participants: [Participant] = []
    @Published var isLoading: Bool = false
    @Published var isOffline: Bool = false
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager()
    private let participantViewModel: ParticipantViewModel
    private let tripId: Int
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "network.monitor")
    private var cacheTimestamp: Date?
    private var pendingItems: [PendingItem] = []
    private let coreDataStack = CoreDataStack.shared
    private let ttl: TimeInterval = 300 // 5 phút
    private var lastParticipantsHash: String? // So sánh participants để tránh trigger lặp

    init(tripId: Int) {
        self.tripId = tripId
        self.participantViewModel = ParticipantViewModel()
        setupNetworkMonitor()
        loadPendingItems()
        if let cachedPackingList = loadFromCache() {
            self.packingList = cachedPackingList
            self.cacheTimestamp = UserDefaults.standard.object(forKey: "packing_list_cache_timestamp_\(tripId)") as? Date
            print("📂 Sử dụng dữ liệu packing list từ cache cho tripId=\(tripId)")
        } else if isOffline {
            showToast(message: "Không có dữ liệu cache và kết nối mạng, vui lòng kết nối lại!")
        }
        // Luôn fetch ngầm khi khởi tạo
        if !isOffline {
            fetchPackingList(forceRefresh: false)
        }
        
        // Fetch participants trước và chỉ xử lý cleanup sau khi có dữ liệu
        fetchParticipants {
            self.participants = self.participantViewModel.participants
            let participantsHash = self.participants.map { "\($0.user.id):\($0.user.username)" }.joined()
            if self.lastParticipantsHash == participantsHash {
                print("⚠️ Bỏ qua participants change vì không có thay đổi thực sự")
                return
            }
            self.lastParticipantsHash = participantsHash
            print("👥 Detected participants change: \(self.participants.map { "\($0.user.id): \($0.user.username), \(String(describing: $0.user.firstName)) \(String(describing: $0.user.lastName))" })")
            
            let validUserIds = Set(self.participants.map { $0.user.id })
            
            let needsUpdateShared = self.cleanupInvalidOwners(in: &self.packingList.sharedItems, validUserIds: validUserIds)
            let needsUpdatePersonal = self.cleanupInvalidOwners(in: &self.packingList.personalItems, validUserIds: validUserIds)
            
            if needsUpdateShared || needsUpdatePersonal {
                print("🔄 Cần làm mới packing list do userIds không hợp lệ")
                self.fetchPackingList(forceRefresh: true) {
                    print("✅ Đã làm mới packing list từ API sau khi cập nhật participants")
                    self.saveToCache(packingList: self.packingList)
                    self.showToast(message: "Đã cập nhật danh sách vật dụng sau khi thay đổi thành viên")
                }
            }
            
            if self.packingList.sharedItems.isEmpty && self.packingList.personalItems.isEmpty || self.isCacheExpired() {
                self.fetchPackingList(forceRefresh: true) {
                    print("✅ Đã làm mới packing list từ API")
                }
            }
        }
        
    }

    private func isCacheExpired() -> Bool {
        guard let ts = cacheTimestamp else { return true }
        return Date().timeIntervalSince(ts) > ttl
    }

    private func cleanupInvalidOwners(in items: inout [PackingItem], validUserIds: Set<Int>) -> Bool {
        guard !validUserIds.isEmpty else {
            print("⚠️ Danh sách validUserIds rỗng, bỏ qua cleanup để tránh mất userId")
            return false
        }
        
        var needsUpdate = false
        
        items = items.map { item in
            var updatedItem = item
            if let userId = item.userId, !validUserIds.contains(userId) {
                updatedItem.userId = nil
                needsUpdate = true
                if !isOffline {
                    self.updatePackingItem(
                        itemId: item.id,
                        name: item.name,
                        quantity: item.quantity,
                        isShared: item.isShared,
                        isPacked: item.isPacked,
                        userId: nil
                    ) {
                        print("✅ Đã cập nhật userId=nil cho item \(item.id) qua API")
                    } onError: { error in
                        print("❌ Lỗi khi cập nhật item \(item.id): \(error.localizedDescription)")
                    }
                } else {
                    let pending = PendingItem(item: updatedItem, action: .update)
                    pendingItems.append(pending)
                    savePendingItems()
                }
            }
            return updatedItem
        }
        
        return needsUpdate
    }

    func unassignItemsForUser(userId: Int, completion: (() -> Void)? = nil) {
        print("🔄 Bắt đầu bỏ gán các vật dụng cho userId=\(userId)")
        var itemsToUnassign = packingList.sharedItems.filter { $0.userId == userId } + packingList.personalItems.filter { $0.userId == userId }
        
        if itemsToUnassign.isEmpty {
            print("⚠️ Không tìm thấy vật dụng nào được gán cho userId=\(userId)")
            fetchPackingList(forceRefresh: true) {
                print("✅ Đã làm mới danh sách vật dụng sau khi kiểm tra bỏ gán")
                completion?()
            }
            return
        }

        // Cập nhật local trước
        for var item in itemsToUnassign {
            item.userId = nil
            if let index = packingList.sharedItems.firstIndex(where: { $0.id == item.id }) {
                packingList.sharedItems[index] = item
            } else if let index = packingList.personalItems.firstIndex(where: { $0.id == item.id }) {
                packingList.personalItems[index] = item
            }
        }
        saveToCache(packingList: packingList)

        if isOffline {
            for item in itemsToUnassign {
                let pending = PendingItem(item: item, action: .update)
                pendingItems.append(pending)
            }
            savePendingItems()
            showToast(message: "Mạng yếu, đã lưu thay đổi offline!")
            completion?()
            return
        }

        let group = DispatchGroup()
        var updateSuccess = true
        let semaphore = DispatchSemaphore(value: 4)
        for item in itemsToUnassign {
            semaphore.wait()
            group.enter()
            print("📤 Gửi yêu cầu bỏ gán cho vật dụng \(item.name) (ID: \(item.id))")
            updatePackingItem(
                itemId: item.id,
                name: item.name,
                quantity: item.quantity,
                isShared: item.isShared,
                isPacked: item.isPacked,
                userId: nil
            ) { [weak self] in
                defer {
                    group.leave()
                    semaphore.signal()
                }
                print("✅ Đã cập nhật userId=nil cho item \(item.id) qua API")
            } onError: { [weak self] error in
                defer {
                    group.leave()
                    semaphore.signal()
                }
                updateSuccess = false
                print("❌ Lỗi khi cập nhật vật dụng \(item.id): \(error.localizedDescription)")
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else {
                completion?()
                return
            }
            if updateSuccess {
                print("✅ Hoàn tất bỏ gán các vật dụng cho userId=\(userId)")
                self.showToast(message: "Đã bỏ gán các vật dụng cho thành viên")
            } else {
                print("❌ Có lỗi khi bỏ gán các vật dụng cho userId=\(userId)")
                self.showToast(message: "Lỗi khi bỏ gán vật dụng")
            }
            self.fetchPackingList(forceRefresh: true) {
                print("✅ Đã làm mới danh sách vật dụng sau khi bỏ gán")
                completion?()
            }
        }
    }

    func fetchPackingList(forceRefresh: Bool = false, completion: (() -> Void)? = nil) {
        if !forceRefresh {
            if !packingList.sharedItems.isEmpty || !packingList.personalItems.isEmpty, let ts = cacheTimestamp, Date().timeIntervalSince(ts) < ttl {
                print("📂 Cache còn hiệu lực, bỏ qua fetch")
                completion?()
                return
            }
        }
        
        if isOffline {
            showToast(message: "Không có kết nối mạng, sử dụng dữ liệu cache")
            completion?()
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ Invalid URL or Token")
            showToast(message: "URL hoặc token không hợp lệ")
            completion?()
            return
        }

        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: PackingListResponse.self)
            .sink { [weak self] completionResult in
                self?.isLoading = false
                self?.handleCompletion(completionResult, completionHandler: completion)
            } receiveValue: { [weak self] response in
                guard let self, response.success else {
                    print("❌ Failed to fetch packing list")
                    self?.showToast(message: "Không thể tải danh sách đồ")
                    completion?()
                    return
                }
                let items = response.data.tripItems.map { item in
                    PackingItem(
                        id: item.id,
                        name: item.name,
                        isPacked: item.isPacked,
                        isShared: item.isShared,
                        userId: item.userId,
                        quantity: item.quantity,
                        note: item.note
                    )
                }
                let newPackingList = PackingList(
                    sharedItems: items.filter { $0.isShared },
                    personalItems: items.filter { !$0.isShared }
                )
                // Kiểm tra thay đổi thực sự
                if self.packingList == newPackingList {
                    print("⚠️ Bỏ qua cập nhật packingList vì không có thay đổi")
                    completion?()
                    return
                }
                self.packingList = newPackingList
                self.saveToCache(packingList: self.packingList)
                print("✅ Đã cập nhật packing list từ API cho tripId=\(self.tripId)")
                completion?()
            }
            .store(in: &cancellables)
    }

    func createPackingItem(name: String, quantity: Int, isShared: Bool, isPacked: Bool = false, userId: Int? = nil, completion: (() -> Void)? = nil) {
        guard !name.isEmpty else {
            print("❌ Tên vật dụng rỗng")
            showToast(message: "Vui lòng nhập tên vật dụng")
            completion?()
            return
        }
        
        if let userId = userId, isOffline {
            showToast(message: "Không thể gán người dùng khi offline")
            return
        }

        // Tạo temp id nếu cần, nhưng giả sử server generate id, dùng temp negative id
        let tempId = generateTempId()
        let newItem = PackingItem(
            id: tempId,
            name: name,
            isPacked: isPacked,
            isShared: isShared,
            userId: userId,
            quantity: quantity,
            note: nil
        )

        if newItem.isShared {
            packingList.sharedItems.append(newItem)
        } else {
            packingList.personalItems.append(newItem)
        }
        saveToCache(packingList: packingList)

        if isOffline {
            let pending = PendingItem(item: newItem, action: .create)
            pendingItems.append(pending)
            savePendingItems()
            showToast(message: "Mạng yếu, đã lưu thay đổi offline!")
            completion?()
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            // Rollback nếu fail
            removeItem(with: tempId)
            saveToCache(packingList: packingList)
            print("❌ URL hoặc token không hợp lệ")
            showToast(message: "URL hoặc token không hợp lệ")
            completion?()
            return
        }

        let body = CreatePackingItemRequest(name: name, quantity: quantity, isShared: isShared, isPacked: isPacked, userId: userId)
        
        do {
            let bodyData = try JSONEncoder().encode(body)
            let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: bodyData)
            isLoading = true
            
            networkManager.performRequest(request, decodeTo: CreatePackingItemResponse.self)
                .sink { [weak self] completionResult in
                    self?.isLoading = false
                    switch completionResult {
                    case .failure(let error):
                        self?.removeItem(with: tempId)
                        self?.saveToCache(packingList: self?.packingList ?? PackingList(sharedItems: [], personalItems: []))
                        if (error as? URLError)?.code == .notConnectedToInternet {
                            let pending = PendingItem(item: newItem, action: .create)
                            self?.pendingItems.append(pending)
                            self?.savePendingItems()
                            self?.showToast(message: "Mạng yếu, đã lưu thay đổi offline!")
                        } else {
                            self?.showToast(message: "Lỗi khi tạo vật dụng: \(error.localizedDescription)")
                        }
                    case .finished:
                        ()
                    }
                    completion?()
                } receiveValue: { [weak self] response in
                    guard let self, response.success else {
                        self?.removeItem(with: tempId)
                        self?.saveToCache(packingList: self?.packingList ?? PackingList(sharedItems: [], personalItems: []))
                        print("❌ Lỗi API khi tạo vật dụng")
                        self?.showToast(message: "Không thể tạo vật dụng")
                        return
                    }

                    let data = response.data
                    let updatedItem = PackingItem(
                        id: data.id,
                        name: data.name,
                        isPacked: data.isPacked,
                        isShared: data.isShared,
                        userId: data.userId,
                        quantity: data.quantity,
                        note: data.note
                    )

                    self.replaceItem(tempId: tempId, with: updatedItem)
                    self.saveToCache(packingList: self.packingList)
                    self.showToast(message: "Đã tạo vật dụng \(updatedItem.name) thành công")
                    print("✅ Đã tạo vật dụng: \(updatedItem.name) (ID: \(updatedItem.id))")
                }
                .store(in: &cancellables)
        } catch {
            removeItem(with: tempId)
            saveToCache(packingList: packingList)
            print("❌ Lỗi mã hóa dữ liệu: \(error.localizedDescription)")
            showToast(message: "Lỗi khi chuẩn bị dữ liệu")
            completion?()
        }
    }

    func updatePackingItem(itemId: Int, name: String, quantity: Int, isShared: Bool, isPacked: Bool, userId: Int?, completion: @escaping () -> Void, onError: @escaping (Error) -> Void = { _ in }) {
        guard !name.isEmpty else {
            print("❌ Tên vật dụng rỗng")
            showToast(message: "Vui lòng nhập tên vật dụng")
            onError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tên vật dụng rỗng"]))
            return
        }
        
        if userId != nil, isOffline {
            showToast(message: "Không thể gán người dùng khi offline")
            return
        }

        // Cập nhật local trước
        var updatedItem: PackingItem?
        if let index = packingList.sharedItems.firstIndex(where: { $0.id == itemId }) {
            packingList.sharedItems[index].name = name
            packingList.sharedItems[index].quantity = quantity
            packingList.sharedItems[index].isShared = isShared
            packingList.sharedItems[index].isPacked = isPacked
            packingList.sharedItems[index].userId = userId
            updatedItem = packingList.sharedItems[index]
            if !isShared {
                let movedItem = packingList.sharedItems.remove(at: index)
                packingList.personalItems.append(movedItem)
            }
        } else if let index = packingList.personalItems.firstIndex(where: { $0.id == itemId }) {
            packingList.personalItems[index].name = name
            packingList.personalItems[index].quantity = quantity
            packingList.personalItems[index].isShared = isShared
            packingList.personalItems[index].isPacked = isPacked
            packingList.personalItems[index].userId = userId
            updatedItem = packingList.personalItems[index]
            if isShared {
                let movedItem = packingList.personalItems.remove(at: index)
                packingList.sharedItems.append(movedItem)
            }
        }
        saveToCache(packingList: packingList)

        if isOffline {
            if let item = updatedItem {
                let pending = PendingItem(item: item, action: .update)
                pendingItems.append(pending)
                savePendingItems()
                showToast(message: "Mạng yếu, đã lưu thay đổi offline!")
            }
            completion()
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items/\(itemId)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ URL hoặc token không hợp lệ")
            showToast(message: "URL hoặc token không hợp lệ")
            onError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL hoặc token không hợp lệ"]))
            return
        }

        let body = UpdatePackingItemRequest(name: name, quantity: quantity, isShared: isShared, isPacked: isPacked, userId: userId)
        
        do {
            let bodyData = try JSONEncoder().encode(body)
            let request = NetworkManager.createRequest(url: url, method: "PATCH", token: token, body: bodyData)
            isLoading = true
            
            networkManager.performRequest(request, decodeTo: UpdatePackingItemResponse.self)
                .sink { [weak self] completionResult in
                    self?.isLoading = false
                    switch completionResult {
                    case .failure(let error):
                        print("❌ Lỗi API khi cập nhật vật dụng \(itemId): \(error.localizedDescription)")
                        onError(error)
                    case .finished:
                        print("✅ Request completed")
                    }
                } receiveValue: { [weak self] response in
                    guard let self, response.success else {
                        print("❌ Lỗi API khi cập nhật vật dụng \(itemId)")
                        self?.showToast(message: "Không thể cập nhật vật dụng")
                        onError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Lỗi API"]))
                        return
                    }

                    let serverItem = PackingItem(
                        id: response.data.updatedItem.id,
                        name: response.data.updatedItem.name,
                        isPacked: response.data.updatedItem.isPacked,
                        isShared: response.data.updatedItem.isShared,
                        userId: response.data.updatedItem.userId,
                        quantity: response.data.updatedItem.quantity,
                        note: response.data.updatedItem.note
                    )

                    self.replaceItem(tempId: itemId, with: serverItem)
                    self.saveToCache(packingList: self.packingList)
                    print("✅ Đã cập nhật vật dụng \(itemId): name=\(serverItem.name), userId=\(String(describing: serverItem.userId)), isPacked=\(serverItem.isPacked)")
                    completion()
                }
                .store(in: &cancellables)
        } catch {
            print("❌ Lỗi mã hóa dữ liệu: \(error.localizedDescription)")
            showToast(message: "Lỗi khi chuẩn bị dữ liệu")
            onError(error)
        }
    }

    func deletePackingItem(itemId: Int, completion: (() -> Void)? = nil) {
        // Backup item
        var backupItem: PackingItem?
        var isShared: Bool = false
        if let index = packingList.sharedItems.firstIndex(where: { $0.id == itemId }) {
            backupItem = packingList.sharedItems.remove(at: index)
            isShared = true
        } else if let index = packingList.personalItems.firstIndex(where: { $0.id == itemId }) {
            backupItem = packingList.personalItems.remove(at: index)
        }
        saveToCache(packingList: packingList)

        if isOffline {
            if let item = backupItem {
                let pending = PendingItem(item: item, action: .delete)
                pendingItems.append(pending)
                savePendingItems()
                showToast(message: "Mạng yếu, đã lưu thay đổi offline!")
            }
            completion?()
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items/\(itemId)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            // Rollback
            if let item = backupItem {
                if isShared {
                    packingList.sharedItems.append(item)
                } else {
                    packingList.personalItems.append(item)
                }
                saveToCache(packingList: packingList)
            }
            print("❌ Invalid URL or Token for delete request")
            showToast(message: "URL hoặc token không hợp lệ")
            completion?()
            return
        }

        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: DeletePackingItemResponse.self)
            .sink { [weak self] completionResult in
                self?.isLoading = false
                switch completionResult {
                case .failure(let error):
                    // Rollback
                    if let item = backupItem {
                        if isShared {
                            self?.packingList.sharedItems.append(item)
                        } else {
                            self?.packingList.personalItems.append(item)
                        }
                        self?.saveToCache(packingList: self?.packingList ?? PackingList(sharedItems: [], personalItems: []))
                    }
                    print("❌ Lỗi khi xóa vật dụng \(itemId): \(error.localizedDescription)")
                    self?.showToast(message: "Lỗi khi xóa vật dụng")
                case .finished:
                    print("✅ Xóa vật dụng thành công")
                }
                completion?()
            } receiveValue: { [weak self] response in
                guard let self else {
                    print("❌ Self is nil, cannot process response")
                    return
                }
                guard response.success else {
                    // Rollback
                    if let item = backupItem {
                        if isShared {
                            self.packingList.sharedItems.append(item)
                        } else {
                            self.packingList.personalItems.append(item)
                        }
                        self.saveToCache(packingList: self.packingList)
                    }
                    print("❌ Lỗi API khi xóa vật dụng \(itemId): \(response.message)")
                    self.showToast(message: response.message)
                    return
                }

                self.showToast(message: "Đã xóa vật dụng")
            }
            .store(in: &cancellables)
    }

    func fetchParticipants(completion: (() -> Void)? = nil) {
        participantViewModel.fetchParticipants(tripId: tripId) {
            print("✅ Đã làm mới danh sách participants từ API")
            completion?()
        }
    }

    func currentItems(for tab: PackingListView.TabType) -> [PackingItem] {
        switch tab {
        case .shared:
            return packingList.sharedItems
        case .personal:
            return packingList.personalItems
        }
    }

    func binding(for item: PackingItem, in tab: PackingListView.TabType) -> Binding<Bool> {
        switch tab {
        case .shared:
            guard let index = packingList.sharedItems.firstIndex(where: { $0.id == item.id }) else {
                print("❌ Không tìm thấy item \(item.id) trong danh sách chung")
                return .constant(false)
            }
            return Binding(
                get: { self.packingList.sharedItems[index].isPacked },
                set: { newValue in
                    if self.packingList.sharedItems[index].isPacked != newValue {
                        let oldValue = self.packingList.sharedItems[index].isPacked
                        self.packingList.sharedItems[index].isPacked = newValue
                        self.saveToCache(packingList: self.packingList)
                        if self.isOffline {
                            let pending = PendingItem(item: self.packingList.sharedItems[index], action: .update)
                            self.pendingItems.append(pending)
                            self.savePendingItems()
                            self.showToast(message: "Mạng yếu, đã lưu thay đổi offline!")
                        } else {
                            self.updatePackingItem(
                                itemId: item.id,
                                name: self.packingList.sharedItems[index].name,
                                quantity: self.packingList.sharedItems[index].quantity,
                                isShared: self.packingList.sharedItems[index].isShared,
                                isPacked: newValue,
                                userId: self.packingList.sharedItems[index].userId
                            ) {
                                print("✅ Đã cập nhật isPacked cho shared item \(item.id) qua API")
                            } onError: { error in
                                self.packingList.sharedItems[index].isPacked = oldValue
                                self.saveToCache(packingList: self.packingList)
                                print("❌ Lỗi khi cập nhật isPacked cho shared item \(item.id): \(error.localizedDescription)")
                            }
                        }
                    }
                }
            )
        case .personal:
            guard let index = packingList.personalItems.firstIndex(where: { $0.id == item.id }) else {
                print("❌ Không tìm thấy item \(item.id) trong danh sách cá nhân")
                return .constant(false)
            }
            return Binding(
                get: { self.packingList.personalItems[index].isPacked },
                set: { newValue in
                    if self.packingList.personalItems[index].isPacked != newValue {
                        let oldValue = self.packingList.personalItems[index].isPacked
                        self.packingList.personalItems[index].isPacked = newValue
                        self.saveToCache(packingList: self.packingList)
                        if self.isOffline {
                            let pending = PendingItem(item: self.packingList.personalItems[index], action: .update)
                            self.pendingItems.append(pending)
                            self.savePendingItems()
                            self.showToast(message: "Mạng yếu, đã lưu thay đổi offline!")
                        } else {
                            self.updatePackingItem(
                                itemId: item.id,
                                name: self.packingList.personalItems[index].name,
                                quantity: self.packingList.personalItems[index].quantity,
                                isShared: self.packingList.personalItems[index].isShared,
                                isPacked: newValue,
                                userId: self.packingList.personalItems[index].userId
                            ) {
                                print("✅ Đã cập nhật isPacked cho personal item \(item.id) qua API")
                            } onError: { error in
                                self.packingList.personalItems[index].isPacked = oldValue
                                self.saveToCache(packingList: self.packingList)
                                print("❌ Lỗi khi cập nhật isPacked cho personal item \(item.id): \(error.localizedDescription)")
                            }
                        }
                    }
                }
            )
        }
    }

    func ownerInitials(for item: PackingItem) -> String {
        guard let userId = item.userId else {
            return ""
        }
        guard let participant = participants.first(where: { $0.user.id == userId }) else {
            // Update userId to nil
            if !isOffline {
                if let index = packingList.sharedItems.firstIndex(where: { $0.id == item.id }) {
                    packingList.sharedItems[index].userId = nil
                    updatePackingItem(
                        itemId: item.id,
                        name: item.name,
                        quantity: item.quantity,
                        isShared: item.isShared,
                        isPacked: item.isPacked,
                        userId: nil
                    ) {
                        print("✅ Đã cập nhật userId=nil cho shared item \(item.id) do participant không tồn tại")
                        self.saveToCache(packingList: self.packingList)
                    } onError: { error in
                        print("❌ Lỗi khi cập nhật userId=nil cho shared item \(item.id): \(error.localizedDescription)")
                    }
                } else if let index = packingList.personalItems.firstIndex(where: { $0.id == item.id }) {
                    packingList.personalItems[index].userId = nil
                    updatePackingItem(
                        itemId: item.id,
                        name: item.name,
                        quantity: item.quantity,
                        isShared: item.isShared,
                        isPacked: item.isPacked,
                        userId: nil
                    ) {
                        print("✅ Đã cập nhật userId=nil cho personal item \(item.id) do participant không tồn tại")
                        self.saveToCache(packingList: self.packingList)
                    } onError: { error in
                        print("❌ Lỗi khi cập nhật userId=nil cho personal item \(item.id): \(error.localizedDescription)")
                    }
                }
            } else {
                if let index = packingList.sharedItems.firstIndex(where: { $0.id == item.id }) {
                    packingList.sharedItems[index].userId = nil
                    let pending = PendingItem(item: packingList.sharedItems[index], action: .update)
                    pendingItems.append(pending)
                    savePendingItems()
                } else if let index = packingList.personalItems.firstIndex(where: { $0.id == item.id }) {
                    packingList.personalItems[index].userId = nil
                    let pending = PendingItem(item: packingList.personalItems[index], action: .update)
                    pendingItems.append(pending)
                    savePendingItems()
                }
                saveToCache(packingList: packingList)
            }
            return ""
        }
        let firstInitial = participant.user.firstName?.prefix(1) ?? ""
        let lastInitial = participant.user.lastName?.prefix(1) ?? ""
        return "\(firstInitial)\(lastInitial)"
    }

    func assignItem(itemId: Int, to userId: Int?) {
        guard let index = packingList.sharedItems.firstIndex(where: { $0.id == itemId }) else {
            print("❌ Item \(itemId) not found in shared items")
            showToast(message: "Không tìm thấy vật dụng")
            return
        }
        let oldUserId = packingList.sharedItems[index].userId
        if oldUserId == userId {
            print("⚠️ No change in userId for item \(itemId)")
            return
        }
        if userId != nil, isOffline {
            showToast(message: "Không thể gán người dùng khi offline")
            return
        }
        packingList.sharedItems[index].userId = userId
        saveToCache(packingList: packingList)
        if isOffline {
            let pending = PendingItem(item: packingList.sharedItems[index], action: .update)
            pendingItems.append(pending)
            savePendingItems()
            showToast(message: "Mạng yếu, đã lưu thay đổi offline!")
            return
        }
        updatePackingItem(
            itemId: itemId,
            name: packingList.sharedItems[index].name,
            quantity: packingList.sharedItems[index].quantity,
            isShared: packingList.sharedItems[index].isShared,
            isPacked: packingList.sharedItems[index].isPacked,
            userId: userId
        ) {
            print("✅ Completed assignItem for shared item \(itemId): userId=\(String(describing: userId))")
        } onError: { error in
            self.packingList.sharedItems[index].userId = oldUserId
            self.saveToCache(packingList: self.packingList)
            print("❌ Lỗi khi gán item \(itemId): \(error.localizedDescription)")
        }
    }

    private func handleCompletion(_ completion: Subscribers.Completion<Error>, completionHandler: (() -> Void)? = nil) {
        switch completion {
        case .failure(let error):
            print("❌ Error performing request: \(error.localizedDescription)")
            showToast(message: "Lỗi khi thực hiện hành động")
        case .finished:
            print("✅ Request completed")
        }
        completionHandler?()
    }

    private func saveToCache(packingList: PackingList) {
        let context = coreDataStack.context
        clearCoreDataCache()
        for item in packingList.sharedItems + packingList.personalItems {
            _ = item.toEntity(context: context, tripId: tripId)
        }
        do {
            try context.save()
            UserDefaults.standard.set(Date(), forKey: "packing_list_cache_timestamp_\(tripId)")
            self.cacheTimestamp = Date()
            print("💾 Đã lưu cache packing list cho tripId=\(tripId)")
        } catch {
            print("Lỗi lưu Core Data: \(error.localizedDescription)")
        }
    }

    private func loadFromCache() -> PackingList? {
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<PackingItemEntity> = PackingItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tripId == %d", tripId)
        do {
            let entities = try context.fetch(fetchRequest)
            let items = entities.map { PackingItem(from: $0) }
            let shared = items.filter { $0.isShared }
            let personal = items.filter { !$0.isShared }
            print("Đọc cache packing list thành công cho tripId=\(tripId)")
            return items.isEmpty ? nil : PackingList(sharedItems: shared, personalItems: personal)
        } catch {
            print("Lỗi khi đọc cache packing list: \(error.localizedDescription)")
            return nil
        }
    }

    private func clearCoreDataCache() {
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PackingItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tripId == %d", tripId)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            coreDataStack.saveContext()
            print("🗑️ Đã xóa cache PackingItemEntity cho tripId=\(tripId)")
        } catch {
            print("Lỗi xóa cache: \(error.localizedDescription)")
        }
    }

    func clearCacheOnLogout() {
        packingList = PackingList(sharedItems: [], personalItems: [])
        pendingItems = []
        clearCoreDataCache()
        UserDefaults.standard.removeObject(forKey: "pending_packing_items_\(tripId)")
        UserDefaults.standard.removeObject(forKey: "packing_list_cache_timestamp_\(tripId)")
        UserDefaults.standard.removeObject(forKey: "next_temp_packing_id_\(tripId)")
        cacheTimestamp = nil
        print("🗑️ Đã xóa toàn bộ cache packing list cho tripId=\(tripId)")
    }

    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOffline = path.status != .satisfied
                if !(self?.isOffline ?? true) {
                    self?.syncPendingItems()
                }
            }
        }
        networkMonitor.start(queue: queue)
    }

    private func generateTempId() -> Int {
        var nextTempId = UserDefaults.standard.integer(forKey: "next_temp_packing_id_\(tripId)")
        if nextTempId >= 0 {
            nextTempId = -1
        }
        nextTempId -= 1
        UserDefaults.standard.set(nextTempId, forKey: "next_temp_packing_id_\(tripId)")
        return nextTempId
    }

    private func savePendingItems() {
        do {
            let data = try JSONEncoder().encode(pendingItems)
            UserDefaults.standard.set(data, forKey: "pending_packing_items_\(tripId)")
            print("💾 Đã lưu \(pendingItems.count) pending items cho tripId=\(tripId)")
        } catch {
            print("Lỗi khi lưu pending items: \(error.localizedDescription)")
        }
    }

    private func loadPendingItems() {
        guard let data = UserDefaults.standard.data(forKey: "pending_packing_items_\(tripId)") else {
            return
        }
        do {
            pendingItems = try JSONDecoder().decode([PendingItem].self, from: data)
            print("Đọc thành công \(pendingItems.count) pending items cho tripId=\(tripId)")
        } catch {
            print("Lỗi khi đọc pending items: \(error.localizedDescription)")
        }
    }

    private func syncPendingItems() {
        guard !pendingItems.isEmpty, !isOffline else { return }
        
        for pending in pendingItems {
            guard let token = UserDefaults.standard.string(forKey: "authToken") else { continue }
            
            switch pending.action {
            case .create:
                let body = CreatePackingItemRequest(name: pending.item.name, quantity: pending.item.quantity, isShared: pending.item.isShared, isPacked: pending.item.isPacked, userId: pending.item.userId)
                guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items"),
                      let bodyData = try? JSONEncoder().encode(body) else { continue }
                let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: bodyData)
                networkManager.performRequest(request, decodeTo: CreatePackingItemResponse.self)
                    .sink { _ in } receiveValue: { [weak self] response in
                        if response.success {
                            let updatedItem = PackingItem(id: response.data.id, name: response.data.name, isPacked: response.data.isPacked, isShared: response.data.isShared, userId: response.data.userId, quantity: response.data.quantity, note: response.data.note)
                            self?.replaceItem(tempId: pending.item.id, with: updatedItem)
                            self?.saveToCache(packingList: self?.packingList ?? PackingList(sharedItems: [], personalItems: []))
                            self?.removePending(with: pending.item.id)
                            self?.showToast(message: "Đã đồng bộ tạo vật dụng")
                        }
                    }
                    .store(in: &cancellables)
            case .update:
                let body = UpdatePackingItemRequest(name: pending.item.name, quantity: pending.item.quantity, isShared: pending.item.isShared, isPacked: pending.item.isPacked, userId: pending.item.userId)
                guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items/\(pending.item.id)"),
                      let bodyData = try? JSONEncoder().encode(body) else { continue }
                let request = NetworkManager.createRequest(url: url, method: "PATCH", token: token, body: bodyData)
                networkManager.performRequest(request, decodeTo: UpdatePackingItemResponse.self)
                    .sink { _ in } receiveValue: { [weak self] response in
                        if response.success {
                            let updatedItem = PackingItem(id: response.data.updatedItem.id, name: response.data.updatedItem.name, isPacked: response.data.updatedItem.isPacked, isShared: response.data.updatedItem.isShared, userId: response.data.updatedItem.userId, quantity: response.data.updatedItem.quantity, note: response.data.updatedItem.note)
                            self?.replaceItem(tempId: pending.item.id, with: updatedItem)
                            self?.saveToCache(packingList: self?.packingList ?? PackingList(sharedItems: [], personalItems: []))
                            self?.removePending(with: pending.item.id)
                            self?.showToast(message: "Đã đồng bộ cập nhật vật dụng")
                        }
                    }
                    .store(in: &cancellables)
            case .delete:
                guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items/\(pending.item.id)") else { continue }
                let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
                networkManager.performRequest(request, decodeTo: DeletePackingItemResponse.self)
                    .sink { _ in } receiveValue: { [weak self] response in
                        if response.success {
                            self?.removePending(with: pending.item.id)
                            self?.showToast(message: "Đã đồng bộ xóa vật dụng")
                        }
                    }
                    .store(in: &cancellables)
            }
        }
    }

    private func removePending(with id: Int) {
        pendingItems.removeAll { $0.item.id == id }
        savePendingItems()
    }

    private func replaceItem(tempId: Int, with newItem: PackingItem) {
        if let index = packingList.sharedItems.firstIndex(where: { $0.id == tempId }) {
            packingList.sharedItems[index] = newItem
        } else if let index = packingList.personalItems.firstIndex(where: { $0.id == tempId }) {
            packingList.personalItems[index] = newItem
        }
    }

    private func removeItem(with id: Int) {
        packingList.sharedItems.removeAll { $0.id == id }
        packingList.personalItems.removeAll { $0.id == id }
    }

    private func showToast(message: String) {
        print("📢 Setting toast: \(message)")
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("📢 Hiding toast")
            self.showToast = false
            self.toastMessage = nil
        }
    }

    func initials(for user: User) -> String {
        let first = user.firstName?.prefix(1) ?? ""
        let last = user.lastName?.prefix(1) ?? ""
        return "\(first)\(last)"
    }

    func checkAndFetchIfNeeded() {
        fetchPackingList(forceRefresh: isCacheExpired())
    }
}

