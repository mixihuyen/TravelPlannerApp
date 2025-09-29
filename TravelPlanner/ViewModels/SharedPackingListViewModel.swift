//import Foundation
//import Combine
//import SwiftUI
//import CoreData
//import Network
//
//class SharedPackingListViewModel: ObservableObject {
//    @Published var sharedItems: [PackingItem] = []
//    @Published var participants: [Participant] = []
//    @Published var isLoading: Bool = false
//    @Published var isOffline: Bool = false
//    @Published var toastMessage: String? = nil
//    @Published var toastType: ToastType?
//    @Published var showToast: Bool = false
//
//    private var cancellables = Set<AnyCancellable>()
//    private let networkManager = NetworkManager.shared
//    private let participantViewModel: ParticipantViewModel
//    private let tripId: Int
//    private let networkMonitor = NWPathMonitor()
//    private let queue = DispatchQueue(label: "network.monitor.shared")
//    private var cacheTimestamp: Date?
//    private var pendingItems: [PendingItem] = []
//    private let coreDataStack = CoreDataStack.shared
//    private let ttl: TimeInterval = 300
//    private var lastParticipantsHash: String?
//    private let currentUserId: Int
//
//    init(tripId: Int) {
//        self.tripId = tripId
//        self.currentUserId = UserDefaults.standard.integer(forKey: "userId")
//        self.participantViewModel = ParticipantViewModel()
//        setupNetworkMonitor()
//        loadPendingItems()
//        if let cachedItems = loadFromCache() {
//            self.sharedItems = cachedItems
//            self.cacheTimestamp = UserDefaults.standard.object(forKey: "shared_packing_list_cache_timestamp_\(tripId)") as? Date
//            print("📂 Sử dụng dữ liệu shared packing list từ cache cho tripId=\(tripId)")
//        } else if isOffline {
//            showToast(message: "Không có dữ liệu cache và kết nối mạng, vui lòng kết nối lại!", type: .error)
//        }
//        if !isOffline {
//            fetchSharedItems(forceRefresh: false)
//        }
//        fetchParticipants {
//            self.participants = self.participantViewModel.participants
//            let participantsHash = self.participants.map { "\($0.userInformation.id):\($0.userInformation.username)" }.joined()
//            if self.lastParticipantsHash == participantsHash {
//                print("⚠️ Bỏ qua participants change vì không có thay đổi thực sự")
//                return
//            }
//            self.lastParticipantsHash = participantsHash
//
//            let validUserIds = Set(self.participants.map { $0.userInformation.id })
//
//            let needsUpdate = self.cleanupInvalidOwners(in: &self.sharedItems, validUserIds: validUserIds)
//
//            if needsUpdate || self.sharedItems.isEmpty || self.isCacheExpired() {
//                self.fetchSharedItems(forceRefresh: true) {
//                    print("✅ Đã làm mới shared packing list từ API")
//                    self.saveToCache()
//                    self.showToast(message: "Đã cập nhật danh sách vật dụng sau khi thay đổi thành viên", type: .success)
//                }
//            }
//        }
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(handleLogout),
//            name: .didLogout,
//            object: nil
//        )
//    }
//
//    @objc private func handleLogout() {
//        clearCacheOnLogout()
//    }
//
//    deinit {
//        NotificationCenter.default.removeObserver(self, name: .didLogout, object: nil)
//    }
//
//    func clearCacheOnLogout() {
//        sharedItems = []
//        participants = []
//        pendingItems = []
//        cacheTimestamp = nil
//        lastParticipantsHash = nil
//        print("🗑️ Đã xóa cache của SharedPackingListViewModel cho tripId=\(tripId)")
//    }
//
//    private func isCacheExpired() -> Bool {
//        guard let ts = cacheTimestamp else { return true }
//        return Date().timeIntervalSince(ts) > ttl
//    }
//
//    private func cleanupInvalidOwners(in items: inout [PackingItem], validUserIds: Set<Int>) -> Bool {
//        guard !validUserIds.isEmpty else {
//            print("⚠️ Danh sách validUserIds rỗng, bỏ qua cleanup để tránh mất userId")
//            return false
//        }
//
//        var needsUpdate = false
//
//        items = items.map { item in
//            var updatedItem = item
//            if let assignedToUserId = item.assignedToUserId, !validUserIds.contains(assignedToUserId) {
//                updatedItem.assignedToUserId = nil
//                needsUpdate = true
//                if !isOffline {
//                    self.updateSharedItem(
//                        itemId: item.id,
//                        name: item.name,
//                        quantity: item.quantity,
//                        isShared: true,
//                        isPacked: item.isPacked,
//                        assignedToUserId: nil
//                    ) {
//                        print("✅ Đã cập nhật assignedToUserId=nil cho item \(item.id) qua API")
//                    } onError: { error in
//                        print("❌ Lỗi khi cập nhật item \(item.id): \(error.localizedDescription)")
//                        self.showToast(message: "Lỗi khi bỏ gán thành viên cho vật dụng", type: .error)
//                    }
//                } else {
//                    let pending = PendingItem(item: updatedItem, action: .update)
//                    pendingItems.append(pending)
//                    savePendingItems()
//                }
//            }
//            return updatedItem
//        }
//
//        return needsUpdate
//    }
//
//    func updateSharedItem(itemId: Int, name: String, quantity: Int, isShared: Bool, isPacked: Bool, assignedToUserId: Int?, completion: @escaping () -> Void, onError: @escaping (Error) -> Void = { _ in }) {
//        guard !name.isEmpty else {
//            print("❌ Tên vật dụng rỗng")
//            showToast(message: "Vui lòng nhập tên vật dụng", type: .error)
//            onError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tên vật dụng rỗng"]))
//            return
//        }
//
//        if isShared && isOffline {
//            showToast(message: "Không thể cập nhật vật dụng trong tab Chung khi offline", type: .error)
//            onError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể cập nhật trong tab Chung khi offline"]))
//            return
//        }
//
//        var updatedItem: PackingItem?
//        if let index = sharedItems.firstIndex(where: { $0.id == itemId }) {
//            sharedItems[index].name = name
//            sharedItems[index].quantity = quantity
//            sharedItems[index].isShared = isShared
//            sharedItems[index].isPacked = isPacked
//            sharedItems[index].assignedToUserId = assignedToUserId
//            updatedItem = sharedItems[index]
//        }
//        saveToCache()
//
//        if isOffline {
//            if let item = updatedItem {
//                let pending = PendingItem(item: item, action: .update)
//                pendingItems.append(pending)
//                savePendingItems()
//                showToast(message: "Mạng yếu, đã lưu thay đổi offline!", type: .error)
//            }
//            completion()
//            return
//        }
//
//        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items/\(itemId)"),
//              let token = UserDefaults.standard.string(forKey: "authToken") else {
//            print("❌ URL hoặc token không hợp lệ")
//            showToast(message: "URL hoặc token không hợp lệ", type: .error)
//            onError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL hoặc token không hợp lệ"]))
//            return
//        }
//
//        let body = UpdatePackingItemRequest(
//            name: name,
//            quantity: quantity,
//            isShared: isShared,
//            isPacked: isPacked,
//            assignedToUserId: assignedToUserId
//        )
//
//        do {
//            let bodyData = try JSONEncoder().encode(body)
//            print("📤 Request body: \(String(data: bodyData, encoding: .utf8) ?? "Invalid JSON")")
//            let request = NetworkManager.createRequest(url: url, method: "PATCH", token: token, body: bodyData)
//            isLoading = true
//
//            networkManager.performRequest(request, decodeTo: UpdatePackingItemResponse.self)
//                .receive(on: DispatchQueue.main)
//                .sink { [weak self] completionResult in
//                    guard let self else { return }
//                    self.isLoading = false
//                    switch completionResult {
//                    case .failure(let error):
//                        if let item = updatedItem, let index = self.sharedItems.firstIndex(where: { $0.id == itemId }) {
//                            self.sharedItems[index] = item
//                            self.saveToCache()
//                        }
//                        print("❌ Lỗi API khi cập nhật vật dụng \(itemId): \(error.localizedDescription)")
//                        if let decodingError = error as? DecodingError {
//                            switch decodingError {
//                            case .typeMismatch(let type, let context):
//                                print("❌ Type mismatch for type: \(type), context: \(context.debugDescription)")
//                            case .valueNotFound(let type, let context):
//                                print("❌ Value not found for type: \(type), context: \(context.debugDescription)")
//                            case .keyNotFound(let key, let context):
//                                print("❌ Key not found: \(key), context: \(context.debugDescription)")
//                            case .dataCorrupted(let context):
//                                print("❌ Data corrupted: \(context.debugDescription)")
//                            @unknown default:
//                                print("❌ Unknown decoding error: \(decodingError)")
//                            }
//                        }
//                        onError(error)
//                        self.showToast(message: "Không thể cập nhật vật dụng: \(error.localizedDescription)", type: .error)
//                    case .finished:
//                        print("✅ Request completed")
//                    }
//                } receiveValue: { [weak self] response in
//                    guard let self else { return }
//                    guard response.success else {
//                        if let item = updatedItem, let index = self.sharedItems.firstIndex(where: { $0.id == itemId }) {
//                            self.sharedItems[index] = item
//                            self.saveToCache()
//                        }
//                        print("❌ Lỗi API khi cập nhật vật dụng \(itemId): \(response.message)")
//                        self.showToast(message: "Không thể cập nhật vật dụng: \(response.message)", type: .error)
//                        onError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Lỗi API: \(response.message)"]))
//                        return
//                    }
//
//                    let serverItem = PackingItem(
//                        id: response.data.id,
//                        name: response.data.name,
//                        isPacked: response.data.isPacked,
//                        isShared: response.data.isShared,
//                        createdByUserId: response.data.createdByUserId,
//                        assignedToUserId: response.data.assignedToUserId,
//                        quantity: response.data.quantity,
//                        note: response.data.note
//                    )
//
//                    self.replaceItem(tempId: itemId, with: serverItem)
//                    self.saveToCache()
//                    print("✅ Đã cập nhật vật dụng \(itemId): name=\(serverItem.name), assignedToUserId=\(String(describing: serverItem.assignedToUserId)), isPacked=\(serverItem.isPacked)")
//                    completion()
//                }
//                .store(in: &cancellables)
//        } catch {
//            if let item = updatedItem, let index = sharedItems.firstIndex(where: { $0.id == itemId }) {
//                sharedItems[index] = item
//                saveToCache()
//            }
//            print("❌ Lỗi mã hóa dữ liệu: \(error.localizedDescription)")
//            showToast(message: "Lỗi khi chuẩn bị dữ liệu", type: .error)
//            onError(error)
//        }
//    }
//
//    func binding(for item: PackingItem) -> Binding<Bool> {
//        if isOffline {
//            showToast(message: "Không thể cập nhật trạng thái trong tab Chung khi offline", type: .error)
//            return .constant(item.isPacked)
//        }
//
//        guard let index = sharedItems.firstIndex(where: { $0.id == item.id }) else {
//            print("❌ Không tìm thấy item \(item.id) trong danh sách chung")
//            return .constant(false)
//        }
//        return Binding(
//            get: { self.sharedItems[index].isPacked },
//            set: { newValue in
//                if self.sharedItems[index].isPacked != newValue {
//                    let oldValue = self.sharedItems[index].isPacked
//                    self.sharedItems[index].isPacked = newValue
//                    self.saveToCache()
//                    self.updateSharedItem(
//                        itemId: item.id,
//                        name: self.sharedItems[index].name,
//                        quantity: self.sharedItems[index].quantity,
//                        isShared: self.sharedItems[index].isShared,
//                        isPacked: newValue,
//                        assignedToUserId: self.sharedItems[index].assignedToUserId
//                    ) {
//                        print("✅ Đã cập nhật isPacked cho shared item \(item.id) qua API")
//                    } onError: { error in
//                        self.sharedItems[index].isPacked = oldValue
//                        self.saveToCache()
//                        print("❌ Lỗi khi cập nhật isPacked cho shared item \(item.id): \(error.localizedDescription)")
//                        self.showToast(message: "Không thể cập nhật trạng thái vật dụng: \(error.localizedDescription)", type: .error)
//                    }
//                }
//            }
//        )
//    }
//
//    func ownerInitials(for item: PackingItem) -> String {
//        guard let assignedToUserId = item.assignedToUserId else {
//            return ""
//        }
//        guard let participant = participants.first(where: { $0.userInformation.id == assignedToUserId }) else {
//            if let index = sharedItems.firstIndex(where: { $0.id == item.id }) {
//                sharedItems[index].assignedToUserId = nil
//                updateSharedItem(
//                    itemId: item.id,
//                    name: item.name,
//                    quantity: item.quantity,
//                    isShared: item.isShared,
//                    isPacked: item.isPacked,
//                    assignedToUserId: nil
//                ) {
//                    print("✅ Đã cập nhật assignedToUserId=nil cho shared item \(item.id) do participant không tồn tại")
//                    self.saveToCache()
//                } onError: { error in
//                    print("❌ Lỗi khi cập nhật assignedToUserId=nil cho shared item \(item.id): \(error.localizedDescription)")
//                    self.showToast(message: "Lỗi khi bỏ gán thành viên cho vật dụng", type: .error)
//                }
//            }
//            return ""
//        }
//        let firstInitial = participant.userInformation.firstName?.prefix(1) ?? ""
//        let lastInitial = participant.userInformation.lastName?.prefix(1) ?? ""
//        return "\(firstInitial)\(lastInitial)"
//    }
//
//    func syncPendingItems() {
//        guard !pendingItems.isEmpty, !isOffline else { return }
//
//        for pending in pendingItems {
//            guard let token = UserDefaults.standard.string(forKey: "authToken") else { continue }
//
//            switch pending.action {
//            case .create:
//                let body = CreatePackingItemRequest(
//                    name: pending.item.name,
//                    quantity: pending.item.quantity,
//                    isShared: true,
//                    isPacked: pending.item.isPacked,
//                    assignedToUserId: pending.item.assignedToUserId
//                )
//                guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items"),
//                      let bodyData = try? JSONEncoder().encode(body) else { continue }
//                let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: bodyData)
//                networkManager.performRequest(request, decodeTo: CreatePackingItemResponse.self)
//                    .receive(on: DispatchQueue.main)
//                    .sink { _ in } receiveValue: { [weak self] response in
//                        if response.success {
//                            let updatedItem = PackingItem(
//                                id: response.data.id,
//                                name: response.data.name,
//                                isPacked: response.data.isPacked,
//                                isShared: response.data.isShared,
//                                createdByUserId: response.data.createdByUserId,
//                                assignedToUserId: response.data.assignedToUserId,
//                                quantity: response.data.quantity,
//                                note: response.data.note
//                            )
//                            self?.replaceItem(tempId: pending.item.id, with: updatedItem)
//                            self?.saveToCache()
//                            self?.removePending(with: pending.item.id)
//                            self?.showToast(message: "Đã đồng bộ tạo vật dụng", type: .success)
//                        }
//                    }
//                    .store(in: &cancellables)
//            case .update:
//                let body = UpdatePackingItemRequest(
//                    name: pending.item.name,
//                    quantity: pending.item.quantity,
//                    isShared: true,
//                    isPacked: pending.item.isPacked,
//                    assignedToUserId: pending.item.assignedToUserId
//                )
//                guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items/\(pending.item.id)"),
//                      let bodyData = try? JSONEncoder().encode(body) else { continue }
//                let request = NetworkManager.createRequest(url: url, method: "PATCH", token: token, body: bodyData)
//                networkManager.performRequest(request, decodeTo: UpdatePackingItemResponse.self)
//                    .receive(on: DispatchQueue.main)
//                    .sink { _ in } receiveValue: { [weak self] response in
//                        if response.success {
//                            let updatedItem = PackingItem(
//                                id: response.data.id,
//                                name: response.data.name,
//                                isPacked: response.data.isPacked,
//                                isShared: response.data.isShared,
//                                createdByUserId: response.data.createdByUserId,
//                                assignedToUserId: response.data.assignedToUserId,
//                                quantity: response.data.quantity,
//                                note: response.data.note
//                            )
//                            self?.replaceItem(tempId: pending.item.id, with: updatedItem)
//                            self?.saveToCache()
//                            self?.removePending(with: pending.item.id)
//                            self?.showToast(message: "Đã đồng bộ cập nhật vật dụng", type: .success)
//                        }
//                    }
//                    .store(in: &cancellables)
//            case .delete:
//                guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items/\(pending.item.id)") else { continue }
//                let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
//                networkManager.performRequest(request, decodeTo: EmptyResponse.self)
//                    .receive(on: DispatchQueue.main)
//                    .sink { _ in } receiveValue: { [weak self] _ in
//                        self?.removePending(with: pending.item.id)
//                        self?.showToast(message: "Đã đồng bộ xóa vật dụng", type: .success)
//                    }
//                    .store(in: &cancellables)
//            }
//        }
//    }
//
//    func unassignItemsForUser(userId: Int, completion: (() -> Void)? = nil) {
//        print("🔄 Bắt đầu bỏ gán các vật dụng cho userId=\(userId)")
//        var itemsToUnassign = sharedItems.filter { $0.assignedToUserId == userId }
//
//        if itemsToUnassign.isEmpty {
//            print("⚠️ Không tìm thấy vật dụng nào được gán cho userId=\(userId)")
//            fetchSharedItems(forceRefresh: true) {
//                print("✅ Đã làm mới danh sách vật dụng sau khi kiểm tra bỏ gán")
//                completion?()
//            }
//            return
//        }
//
//        for var item in itemsToUnassign {
//            item.assignedToUserId = nil
//            if let index = sharedItems.firstIndex(where: { $0.id == item.id }) {
//                sharedItems[index] = item
//            }
//        }
//        saveToCache()
//
//        if isOffline {
//            for item in itemsToUnassign {
//                let pending = PendingItem(item: item, action: .update)
//                pendingItems.append(pending)
//            }
//            savePendingItems()
//            showToast(message: "Mạng yếu, đã lưu thay đổi offline!", type: .error)
//            completion?()
//            return
//        }
//
//        let group = DispatchGroup()
//        var updateSuccess = true
//        let semaphore = DispatchSemaphore(value: 4)
//        for item in itemsToUnassign {
//            semaphore.wait()
//            group.enter()
//            print("📤 Gửi yêu cầu bỏ gán cho vật dụng \(item.name) (ID: \(item.id))")
//            updateSharedItem(
//                itemId: item.id,
//                name: item.name,
//                quantity: item.quantity,
//                isShared: item.isShared,
//                isPacked: item.isPacked,
//                assignedToUserId: nil
//            ) { [weak self] in
//                defer {
//                    group.leave()
//                    semaphore.signal()
//                }
//                print("✅ Đã cập nhật assignedToUserId=nil cho item \(item.id) qua API")
//            } onError: { [weak self] error in
//                defer {
//                    group.leave()
//                    semaphore.signal()
//                }
//                updateSuccess = false
//                print("❌ Lỗi khi cập nhật vật dụng \(item.id): \(error.localizedDescription)")
//            }
//        }
//
//        group.notify(queue: .main) { [weak self] in
//            guard let self else {
//                completion?()
//                return
//            }
//            if updateSuccess {
//                print("✅ Hoàn tất bỏ gán các vật dụng cho userId=\(userId)")
//                self.showToast(message: "Đã bỏ gán các vật dụng cho thành viên", type: .success)
//            } else {
//                print("❌ Có lỗi khi bỏ gán các vật dụng cho userId=\(userId)")
//                self.showToast(message: "Lỗi khi bỏ gán vật dụng", type: .error)
//            }
//            self.fetchSharedItems(forceRefresh: true) {
//                print("✅ Đã làm mới danh sách vật dụng sau khi bỏ gán")
//                completion?()
//            }
//        }
//    }
//
//    func fetchSharedItems(forceRefresh: Bool = false, completion: (() -> Void)? = nil) {
//        if !forceRefresh, !sharedItems.isEmpty, let ts = cacheTimestamp, Date().timeIntervalSince(ts) < ttl {
//            print("📂 Cache còn hiệu lực, bỏ qua fetch")
//            completion?()
//            return
//        }
//
//        if isOffline {
//            showToast(message: "Không có kết nối mạng, sử dụng dữ liệu cache", type: .error)
//            completion?()
//            return
//        }
//
//        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items"),
//              let token = UserDefaults.standard.string(forKey: "authToken") else {
//            print("❌ Invalid URL or Token")
//            showToast(message: "URL hoặc token không hợp lệ", type: .error)
//            completion?()
//            return
//        }
//
//        if isLoading {
//            print("⚠️ Đã có yêu cầu fetchSharedItems đang chạy, bỏ qua")
//            completion?()
//            return
//        }
//
//        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
//        isLoading = true
//        networkManager.performRequest(request, decodeTo: PackingListResponse.self)
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] completionResult in
//                self?.isLoading = false
//                switch completionResult {
//                case .failure(let error):
//                    print("❌ Lỗi khi lấy shared items: \(error.localizedDescription)")
//                    if let decodingError = error as? DecodingError {
//                        switch decodingError {
//                        case .typeMismatch(let type, let context):
//                            print("❌ Type mismatch for type: \(type), context: \(context.debugDescription)")
//                        case .valueNotFound(let type, let context):
//                            print("❌ Value not found for type: \(type), context: \(context.debugDescription)")
//                        case .keyNotFound(let key, let context):
//                            print("❌ Key not found: \(key), context: \(context.debugDescription)")
//                        case .dataCorrupted(let context):
//                            print("❌ Data corrupted: \(context.debugDescription)")
//                        @unknown default:
//                            print("❌ Unknown decoding error: \(decodingError)")
//                        }
//                    }
//                    self?.showToast(message: "Không thể tải danh sách đồ: \(error.localizedDescription)", type: .error)
//                case .finished:
//                    print("✅ Request completed")
//                }
//                self?.handleCompletion(completionResult, completionHandler: completion)
//            } receiveValue: { [weak self] response in
//                guard let self, response.success else {
//                    print("❌ API trả về success=false: \(response.message)")
//                    self?.showToast(message: "Không thể tải danh sách đồ: \(response.message)", type: .error)
//                    completion?()
//                    return
//                }
//                let items = response.data.map { item in
//                    PackingItem(
//                        id: item.id,
//                        name: item.name,
//                        isPacked: item.isPacked,
//                        isShared: item.isShared,
//                        createdByUserId: item.createdByUserId,
//                        assignedToUserId: item.assignedToUserId,
//                        quantity: item.quantity,
//                        note: item.note
//                    )
//                }
//                let newSharedItems = items.filter { $0.isShared }
//                if self.sharedItems == newSharedItems {
//                    print("⚠️ Bỏ qua cập nhật sharedItems vì không có thay đổi")
//                    completion?()
//                    return
//                }
//                self.sharedItems = newSharedItems
//                self.saveToCache()
//                print("✅ Đã cập nhật shared items từ API cho tripId=\(self.tripId), items: \(newSharedItems.count)")
//                completion?()
//            }
//            .store(in: &cancellables)
//    }
//
//    func createSharedItem(name: String, quantity: Int, isShared: Bool, isPacked: Bool = false, assignedToUserId: Int? = nil, completion: (() -> Void)? = nil) {
//        guard !name.isEmpty else {
//            print("❌ Tên vật dụng rỗng")
//            showToast(message: "Vui lòng nhập tên vật dụng", type: .error)
//            completion?()
//            return
//        }
//
//        if isShared && isOffline {
//            showToast(message: "Không thể tạo vật dụng trong tab Chung khi offline", type: .error)
//            return
//        }
//
//        let tempId = generateTempId()
//        let newItem = PackingItem(
//            id: tempId,
//            name: name,
//            isPacked: isPacked,
//            isShared: isShared,
//            createdByUserId: currentUserId,
//            assignedToUserId: assignedToUserId,
//            quantity: quantity,
//            note: nil
//        )
//
//        sharedItems.append(newItem)
//        saveToCache()
//
//        if isOffline {
//            let pending = PendingItem(item: newItem, action: .create)
//            pendingItems.append(pending)
//            savePendingItems()
//            showToast(message: "Mạng yếu, đã lưu thay đổi offline!", type: .error)
//            completion?()
//            return
//        }
//
//        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items"),
//              let token = UserDefaults.standard.string(forKey: "authToken") else {
//            removeItem(with: tempId)
//            saveToCache()
//            print("❌ URL hoặc token không hợp lệ")
//            showToast(message: "URL hoặc token không hợp lệ", type: .error)
//            completion?()
//            return
//        }
//
//        let body = CreatePackingItemRequest(
//            name: name,
//            quantity: quantity,
//            isShared: isShared,
//            isPacked: isPacked,
//            assignedToUserId: assignedToUserId
//        )
//
//        do {
//            let bodyData = try JSONEncoder().encode(body)
//            let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: bodyData)
//            isLoading = true
//
//            networkManager.performRequest(request, decodeTo: CreatePackingItemResponse.self)
//                .receive(on: DispatchQueue.main)
//                .sink { [weak self] completionResult in
//                    self?.isLoading = false
//                    switch completionResult {
//                    case .failure(let error):
//                        self?.removeItem(with: tempId)
//                        self?.saveToCache()
//                        if (error as? URLError)?.code == .notConnectedToInternet {
//                            let pending = PendingItem(item: newItem, action: .create)
//                            self?.pendingItems.append(pending)
//                            self?.savePendingItems()
//                            self?.showToast(message: "Mạng yếu, đã lưu thay đổi offline!", type: .error)
//                        } else {
//                            self?.showToast(message: "Lỗi khi tạo vật dụng: \(error.localizedDescription)", type: .error)
//                        }
//                    case .finished:
//                        ()
//                    }
//                    completion?()
//                } receiveValue: { [weak self] response in
//                    guard let self, response.success else {
//                        self?.removeItem(with: tempId)
//                        self?.saveToCache()
//                        print("❌ Lỗi API khi tạo vật dụng")
//                        self?.showToast(message: "Không thể tạo vật dụng", type: .error)
//                        return
//                    }
//
//                    let updatedItem = PackingItem(
//                        id: response.data.id,
//                        name: response.data.name,
//                        isPacked: response.data.isPacked,
//                        isShared: response.data.isShared,
//                        createdByUserId: response.data.createdByUserId,
//                        assignedToUserId: response.data.assignedToUserId,
//                        quantity: response.data.quantity,
//                        note: response.data.note
//                    )
//
//                    self.replaceItem(tempId: tempId, with: updatedItem)
//                    self.saveToCache()
//                    self.showToast(message: "Đã tạo vật dụng \(updatedItem.name) thành công", type: .success)
//                    print("✅ Đã tạo vật dụng: \(updatedItem.name) (ID: \(updatedItem.id))")
//                }
//                .store(in: &cancellables)
//        } catch {
//            removeItem(with: tempId)
//            saveToCache()
//            print("❌ Lỗi mã hóa dữ liệu: \(error.localizedDescription)")
//            showToast(message: "Lỗi khi chuẩn bị dữ liệu", type: .error)
//            completion?()
//        }
//    }
//
//    func deleteSharedItem(itemId: Int, completion: (() -> Void)? = nil) {
//        let isShared = sharedItems.contains { $0.id == itemId }
//
//        if isShared && isOffline {
//            showToast(message: "Không thể xóa vật dụng trong tab Chung khi offline", type: .error)
//            return
//        }
//
//        var backupItem: PackingItem?
//        if let index = sharedItems.firstIndex(where: { $0.id == itemId }) {
//            backupItem = sharedItems.remove(at: index)
//        }
//        saveToCache()
//
//        if isOffline {
//            if let item = backupItem {
//                let pending = PendingItem(item: item, action: .delete)
//                pendingItems.append(pending)
//                savePendingItems()
//                showToast(message: "Mạng yếu, đã lưu thay đổi offline!", type: .error)
//            }
//            completion?()
//            return
//        }
//
//        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items/\(itemId)"),
//              let token = UserDefaults.standard.string(forKey: "authToken") else {
//            if let item = backupItem {
//                sharedItems.append(item)
//                saveToCache()
//            }
//            print("❌ Invalid URL or Token for delete request")
//            showToast(message: "URL hoặc token không hợp lệ", type: .error)
//            completion?()
//            return
//        }
//
//        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
//        isLoading = true
//        networkManager.performRequest(request, decodeTo: EmptyResponse.self)
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] completionResult in
//                self?.isLoading = false
//                switch completionResult {
//                case .failure(let error):
//                    if let item = backupItem {
//                        self?.sharedItems.append(item)
//                        self?.saveToCache()
//                    }
//                    print("❌ Lỗi khi xóa vật dụng \(itemId): \(error.localizedDescription)")
//                    self?.showToast(message: "Lỗi khi xóa vật dụng: \(error.localizedDescription)", type: .error)
//                case .finished:
//                    print("✅ Xóa vật dụng thành công")
//                    self?.showToast(message: "Đã xóa vật dụng", type: .success)
//                }
//                completion?()
//            } receiveValue: { _ in }
//            .store(in: &cancellables)
//    }
//
//    func fetchParticipants(completion: (() -> Void)? = nil) {
//        participantViewModel.fetchParticipants(tripId: tripId) {
//            print("✅ Đã làm mới danh sách participants từ API")
//            completion?()
//        }
//    }
//
//    func assignItem(itemId: Int, to assignedToUserId: Int?) {
//        guard let index = sharedItems.firstIndex(where: { $0.id == itemId }) else {
//            print("❌ Item \(itemId) not found in shared items")
//            showToast(message: "Không tìm thấy vật dụng", type: .error)
//            return
//        }
//        if isOffline {
//            showToast(message: "Không thể gán người dùng trong tab Chung khi offline", type: .error)
//            return
//        }
//        let oldAssignedToUserId = sharedItems[index].assignedToUserId
//        if oldAssignedToUserId == assignedToUserId {
//            print("⚠️ No change in assignedToUserId for item \(itemId)")
//            return
//        }
//        sharedItems[index].assignedToUserId = assignedToUserId
//        saveToCache()
//        updateSharedItem(
//            itemId: itemId,
//            name: sharedItems[index].name,
//            quantity: sharedItems[index].quantity,
//            isShared: sharedItems[index].isShared,
//            isPacked: sharedItems[index].isPacked,
//            assignedToUserId: assignedToUserId
//        ) {
//            print("✅ Completed assignItem for shared item \(itemId): assignedToUserId=\(String(describing: assignedToUserId))")
//        } onError: { error in
//            self.sharedItems[index].assignedToUserId = oldAssignedToUserId
//            self.saveToCache()
//            print("❌ Lỗi khi gán item \(itemId): \(error.localizedDescription)")
//            self.showToast(message: "Lỗi khi gán thành viên cho vật dụng", type: .error)
//        }
//    }
//
//    private func saveToCache() {
//        let context = coreDataStack.context
//        clearCoreDataCache()
//        for item in sharedItems {
//            _ = item.toEntity(context: context, tripId: tripId)
//        }
//        do {
//            try context.save()
//            CacheManager.shared.saveCacheTimestamp(forKey: "shared_packing_list_cache_timestamp_\(tripId)")
//            self.cacheTimestamp = Date()
//            print("💾 Đã lưu cache shared packing list cho tripId=\(tripId)")
//        } catch {
//            print("Lỗi lưu Core Data: \(error.localizedDescription)")
//        }
//    }
//
//    private func loadFromCache() -> [PackingItem]? {
//        let context = coreDataStack.context
//        let fetchRequest: NSFetchRequest<PackingItemEntity> = PackingItemEntity.fetchRequest()
//        fetchRequest.predicate = NSPredicate(format: "tripId == %d AND isShared == true", tripId)
//        do {
//            let entities = try context.fetch(fetchRequest)
//            let items = entities.map { PackingItem(from: $0) }
//            print("Đọc cache shared packing list thành công cho tripId=\(tripId)")
//            return items.isEmpty ? nil : items
//        } catch {
//            print("Lỗi khi đọc cache shared packing list: \(error.localizedDescription)")
//            return nil
//        }
//    }
//
//    private func clearCoreDataCache() {
//        let context = coreDataStack.context
//        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PackingItemEntity.fetchRequest()
//        fetchRequest.predicate = NSPredicate(format: "tripId == %d AND isShared == true", tripId)
//        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
//        do {
//            try context.execute(deleteRequest)
//            coreDataStack.saveContext()
//            print("🗑️ Đã xóa cache PackingItemEntity cho shared items tripId=\(tripId)")
//        } catch {
//            print("Lỗi xóa cache: \(error.localizedDescription)")
//        }
//    }
//
//    private func setupNetworkMonitor() {
//        networkMonitor.pathUpdateHandler = { [weak self] path in
//            DispatchQueue.main.async {
//                self?.isOffline = path.status != .satisfied
//                if !(self?.isOffline ?? true) {
//                    self?.syncPendingItems()
//                }
//            }
//        }
//        networkMonitor.start(queue: queue)
//    }
//
//    private func generateTempId() -> Int {
//        var nextTempId = UserDefaults.standard.integer(forKey: "next_temp_packing_id_shared_\(tripId)")
//        if nextTempId >= 0 {
//            nextTempId = -1
//        }
//        nextTempId -= 1
//        UserDefaults.standard.set(nextTempId, forKey: "next_temp_packing_id_shared_\(tripId)")
//        return nextTempId
//    }
//
//    private func savePendingItems() {
//        do {
//            let data = try JSONEncoder().encode(pendingItems)
//            UserDefaults.standard.set(data, forKey: "pending_shared_packing_items_\(tripId)")
//            print("💾 Đã lưu \(pendingItems.count) pending shared items cho tripId=\(tripId)")
//        } catch {
//            print("Lỗi khi lưu pending items: \(error.localizedDescription)")
//        }
//    }
//
//    private func loadPendingItems() {
//        guard let data = UserDefaults.standard.data(forKey: "pending_shared_packing_items_\(tripId)") else {
//            return
//        }
//        do {
//            pendingItems = try JSONDecoder().decode([PendingItem].self, from: data)
//            print("Đọc thành công \(pendingItems.count) pending shared items cho tripId=\(tripId)")
//        } catch {
//            print("Lỗi khi đọc pending items: \(error.localizedDescription)")
//        }
//    }
//
//    private func removePending(with id: Int) {
//        pendingItems.removeAll { $0.item.id == id }
//        savePendingItems()
//    }
//
//    private func replaceItem(tempId: Int, with newItem: PackingItem) {
//        if let index = sharedItems.firstIndex(where: { $0.id == tempId }) {
//            sharedItems[index] = newItem
//        }
//    }
//
//    private func removeItem(with id: Int) {
//        sharedItems.removeAll { $0.id == id }
//    }
//
//    private func handleCompletion(_ completion: Subscribers.Completion<Error>, completionHandler: (() -> Void)? = nil) {
//        switch completion {
//        case .failure(let error):
//            print("❌ Error performing request: \(error.localizedDescription)")
//            showToast(message: "Lỗi khi thực hiện hành động", type: .error)
//        case .finished:
//            print("✅ Request completed")
//        }
//        completionHandler?()
//    }
//
//    func showToast(message: String, type: ToastType) {
//        print("📢 Đặt toast: \(message) với type: \(type)")
//        DispatchQueue.main.async {
//            self.toastMessage = message
//            self.toastType = type
//            self.showToast = true
//            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
//                print("📢 Ẩn toast")
//                self.showToast = false
//                self.toastMessage = nil
//                self.toastType = nil
//            }
//        }
//    }
//
//    func initials(for user: UserInformation) -> String {
//        let first = user.firstName?.prefix(1) ?? ""
//        let last = user.lastName?.prefix(1) ?? ""
//        return "\(first)\(last)"
//    }
//
//    func checkAndFetchIfNeeded() {
//        fetchSharedItems(forceRefresh: isCacheExpired())
//    }
//}
