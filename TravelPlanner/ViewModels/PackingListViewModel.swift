import Foundation
import Combine
import SwiftUI

class PackingListViewModel: ObservableObject {
    @Published var packingList: PackingList
    @Published var participants: [Participant] = []
    @Published var isLoading: Bool = false
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager()
    private let participantViewModel: ParticipantViewModel
    private let tripId: Int

    init(tripId: Int) {
        self.tripId = tripId
        self.packingList = PackingList(sharedItems: [], personalItems: [])
        self.participantViewModel = ParticipantViewModel()
        UserDefaults.standard.removeObject(forKey: "packing_list_cache_\(tripId)")
        loadFromCache()
        
        // Đăng ký lắng nghe thay đổi của participants
        participantViewModel.$participants
            .sink { [weak self] newParticipants in
                guard let self else { return }
                print("👥 Detected participants change: \(newParticipants.map { "\($0.user.id): \($0.user.username), \(String(describing: $0.user.firstName)) \(String(describing: $0.user.lastName))" })")
                self.participants = newParticipants
                
                // Kiểm tra và bỏ gán các vật dụng có userId không hợp lệ
                let validUserIds = Set(newParticipants.map { $0.user.id })
                var needsUpdate = false
                
                packingList.sharedItems = packingList.sharedItems.map { item in
                    var updatedItem = item
                    if let userId = item.userId, !validUserIds.contains(userId) {
                        updatedItem.userId = nil
                        needsUpdate = true
                        print("⚠️ Invalid userId=\(userId) in shared item \(item.name), setting to nil")
                        self.updatePackingItem(
                            itemId: item.id,
                            name: item.name,
                            quantity: item.quantity,
                            isShared: item.isShared,
                            isPacked: item.isPacked,
                            userId: nil
                        ) {
                            print("✅ Đã cập nhật userId=nil cho shared item \(item.id) qua API")
                        } onError: { error in
                            print("❌ Lỗi khi cập nhật shared item \(item.id): \(error.localizedDescription)")
                        }
                    }
                    return updatedItem
                }
                
                packingList.personalItems = packingList.personalItems.map { item in
                    var updatedItem = item
                    if let userId = item.userId, !validUserIds.contains(userId) {
                        updatedItem.userId = nil
                        needsUpdate = true
                        print("⚠️ Invalid userId=\(userId) in personal item \(item.name), setting to nil")
                        self.updatePackingItem(
                            itemId: item.id,
                            name: item.name,
                            quantity: item.quantity,
                            isShared: item.isShared,
                            isPacked: item.isPacked,
                            userId: nil
                        ) {
                            print("✅ Đã cập nhật userId=nil cho personal item \(item.id) qua API")
                        } onError: { error in
                            print("❌ Lỗi khi cập nhật personal item \(item.id): \(error.localizedDescription)")
                        }
                    }
                    return updatedItem
                }
                
                if needsUpdate {
                    // Xóa cache và làm mới từ API
                    UserDefaults.standard.removeObject(forKey: "packing_list_cache_\(self.tripId)")
                    print("🗑️ Đã xóa cache packing list do thay đổi participants")
                    self.fetchPackingList {
                        print("✅ Đã làm mới packing list từ API sau khi cập nhật participants")
                        self.saveToCache(packingList: self.packingList)
                        self.showToast(message: "Đã cập nhật danh sách vật dụng sau khi thay đổi thành viên")
                    }
                }
            }
            .store(in: &cancellables)
        
        fetchParticipants {
            self.fetchPackingList()
        }
    }

    func unassignItemsForUser(userId: Int, completion: (() -> Void)? = nil) {
        print("🔄 Bắt đầu bỏ gán các vật dụng cho userId=\(userId)")
        let group = DispatchGroup()
        var updateSuccess = true
        let itemsToUnassign = packingList.sharedItems.filter { $0.userId == userId } + packingList.personalItems.filter { $0.userId == userId }
        
        if itemsToUnassign.isEmpty {
            print("⚠️ Không tìm thấy vật dụng nào được gán cho userId=\(userId)")
            fetchPackingList {
                print("✅ Đã làm mới danh sách vật dụng sau khi kiểm tra bỏ gán")
                completion?()
            }
            return
        }

        // Sử dụng semaphore để kiểm soát số lượng request đồng thời
        let semaphore = DispatchSemaphore(value: 4) // Giới hạn 4 request đồng thời
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
                guard let self else {
                    updateSuccess = false
                    print("❌ Lỗi: self bị giải phóng khi cập nhật vật dụng \(item.id)")
                    return
                }
                if let index = self.packingList.sharedItems.firstIndex(where: { $0.id == item.id }) {
                    self.packingList.sharedItems[index].userId = nil
                    print("✅ Đã cập nhật local userId=nil cho vật dụng chung \(item.name) (ID: \(item.id))")
                } else if let index = self.packingList.personalItems.firstIndex(where: { $0.id == item.id }) {
                    self.packingList.personalItems[index].userId = nil
                    print("✅ Đã cập nhật local userId=nil cho vật dụng cá nhân \(item.name) (ID: \(item.id))")
                } else {
                    updateSuccess = false
                    print("❌ Không tìm thấy vật dụng \(item.name) (ID: \(item.id)) trong danh sách")
                }
                self.saveToCache(packingList: self.packingList)
            } onError: { [weak self] error in
                defer {
                    group.leave()
                    semaphore.signal()
                }
                guard let self else { return }
                updateSuccess = false
                print("❌ Lỗi khi cập nhật vật dụng \(item.id): \(error.localizedDescription)")
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else {
                print("❌ Lỗi: self bị giải phóng khi hoàn tất bỏ gán")
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
            self.fetchPackingList {
                print("✅ Đã làm mới danh sách vật dụng sau khi bỏ gán")
                completion?()
            }
        }
    }

    func fetchPackingList(completion: (() -> Void)? = nil) {
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ Invalid URL or Token")
            showToast(message: "URL hoặc token không hợp lệ")
            isLoading = false
            completion?()
            return
        }

        // Xóa cache để đảm bảo lấy dữ liệu mới từ API
        UserDefaults.standard.removeObject(forKey: "packing_list_cache_\(tripId)")
        print("🗑️ Đã xóa cache packing list cho tripId=\(tripId) trước khi fetch")

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
                self.packingList = PackingList(
                    sharedItems: items.filter { $0.isShared },
                    personalItems: items.filter { !$0.isShared }
                )
                self.saveToCache(packingList: self.packingList)
                print("📋 Successfully fetched packing list: \(items.count) items (\(self.packingList.sharedItems.count) shared, \(self.packingList.personalItems.count) personal)")
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
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ URL hoặc token không hợp lệ")
            showToast(message: "URL hoặc token không hợp lệ")
            completion?()
            return
        }

        let body = CreatePackingItemRequest(name: name, quantity: quantity, isShared: isShared, isPacked: isPacked, userId: userId)
        
        do {
            let bodyData = try JSONEncoder().encode(body)
            if let jsonString = String(data: bodyData, encoding: .utf8) {
                print("📤 Sending create request: \(jsonString)")
            }
            let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: bodyData)
            isLoading = true
            
            networkManager.performRequest(request, decodeTo: CreatePackingItemResponse.self)
                .sink { [weak self] completionResult in
                    self?.isLoading = false
                    self?.handleCompletion(completionResult, completionHandler: completion)
                } receiveValue: { [weak self] response in
                    guard let self, response.success else {
                        print("❌ Lỗi API khi tạo vật dụng")
                        self?.showToast(message: "Không thể tạo vật dụng")
                        completion?()
                        return
                    }

                    let data = response.data
                    let newItem = PackingItem(
                        id: data.id,
                        name: data.name,
                        isPacked: data.isPacked,
                        isShared: data.isShared,
                        userId: data.userId,
                        quantity: data.quantity,
                        note: data.note
                    )

                    if newItem.isShared {
                        self.packingList.sharedItems.append(newItem)
                    } else {
                        self.packingList.personalItems.append(newItem)
                    }

                    self.saveToCache(packingList: self.packingList)
                    self.showToast(message: "Đã tạo vật dụng \(newItem.name) thành công")
                    print("✅ Đã tạo vật dụng: \(newItem.name) (ID: \(newItem.id))")
                    completion?()
                }
                .store(in: &cancellables)
        } catch {
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
            if let jsonString = String(data: bodyData, encoding: .utf8) {
                print("📤 Sending update request for item \(itemId): \(jsonString)")
            }
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

                    let updatedItem = PackingItem(
                        id: response.data.updatedItem.id,
                        name: response.data.updatedItem.name,
                        isPacked: response.data.updatedItem.isPacked,
                        isShared: response.data.updatedItem.isShared,
                        userId: response.data.updatedItem.userId,
                        quantity: response.data.updatedItem.quantity,
                        note: response.data.updatedItem.note
                    )

                    if let index = self.packingList.sharedItems.firstIndex(where: { $0.id == itemId }) {
                        if updatedItem.isShared {
                            self.packingList.sharedItems[index] = updatedItem
                        } else {
                            self.packingList.sharedItems.remove(at: index)
                            self.packingList.personalItems.append(updatedItem)
                        }
                    } else if let index = self.packingList.personalItems.firstIndex(where: { $0.id == itemId }) {
                        if updatedItem.isShared {
                            self.packingList.personalItems.remove(at: index)
                            self.packingList.sharedItems.append(updatedItem)
                        } else {
                            self.packingList.personalItems[index] = updatedItem
                        }
                    }

                    self.saveToCache(packingList: self.packingList)
                    print("✅ Đã cập nhật vật dụng \(itemId): name=\(updatedItem.name), userId=\(String(describing: updatedItem.userId)), isPacked=\(updatedItem.isPacked)")
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
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items/\(itemId)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ Invalid URL or Token for delete request")
            showToast(message: "URL hoặc token không hợp lệ")
            completion?()
            return
        }

        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
        isLoading = true
        print("📤 Sending delete request for item \(itemId)")
        
        networkManager.performRequest(request, decodeTo: DeletePackingItemResponse.self)
            .sink { [weak self] completionResult in
                self?.isLoading = false
                self?.handleCompletion(completionResult, completionHandler: completion)
            } receiveValue: { [weak self] response in
                guard let self, response.success else {
                    print("❌ Lỗi API khi xóa vật dụng \(itemId): \(response.message)")
                    self?.showToast(message: response.message)
                    completion?()
                    return
                }

                if let index = self.packingList.sharedItems.firstIndex(where: { $0.id == itemId }) {
                    let itemName = self.packingList.sharedItems[index].name
                    self.packingList.sharedItems.remove(at: index)
                    self.showToast(message: "Đã xóa vật dụng \(itemName)")
                    print("✅ Đã xóa vật dụng \(itemId) khỏi danh sách chung")
                } else if let index = self.packingList.personalItems.firstIndex(where: { $0.id == itemId }) {
                    let itemName = self.packingList.personalItems[index].name
                    self.packingList.personalItems.remove(at: index)
                    self.showToast(message: "Đã xóa vật dụng \(itemName)")
                    print("✅ Đã xóa vật dụng \(itemId) khỏi danh sách cá nhân")
                }

                self.saveToCache(packingList: self.packingList)
                completion?()
            }
            .store(in: &cancellables)
    }

    func fetchParticipants(completion: (() -> Void)? = nil) {
        participantViewModel.fetchParticipants(tripId: tripId) {
            print("✅ Đã làm mới danh sách participants từ API")
            self.fetchPackingList {
                print("✅ Đã làm mới danh sách vật dụng sau khi cập nhật participants")
                completion?()
            }
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
                        print("🔄 Updating local isPacked for shared item \(item.id): \(self.packingList.sharedItems[index].name) to \(newValue)")
                        self.packingList.sharedItems[index].isPacked = newValue
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
                            print("❌ Lỗi khi cập nhật isPacked cho shared item \(item.id): \(error.localizedDescription)")
                        }
                        self.saveToCache(packingList: self.packingList)
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
                        print("🔄 Updating local isPacked for personal item \(item.id): \(self.packingList.personalItems[index].name) to \(newValue)")
                        self.packingList.personalItems[index].isPacked = newValue
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
                            print("❌ Lỗi khi cập nhật isPacked cho personal item \(item.id): \(error.localizedDescription)")
                        }
                        self.saveToCache(packingList: self.packingList)
                    }
                }
            )
        }
    }

    func ownerInitials(for item: PackingItem) -> String {
        guard let userId = item.userId else {
            print("⚠️ No userId assigned for item \(item.name) (ID: \(item.id))")
            return ""
        }
        guard let participant = participants.first(where: { $0.user.id == userId }) else {
            print("⚠️ No participant found for userId=\(userId) in item \(item.name) (ID: \(item.id))")
            // Cập nhật userId về nil nếu participant không tồn tại
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
            // Xóa cache và làm mới từ API
            UserDefaults.standard.removeObject(forKey: "packing_list_cache_\(tripId)")
            print("🗑️ Đã xóa cache packing list cho tripId=\(tripId)")
            fetchPackingList {
                print("✅ Đã làm mới packing list từ API sau khi phát hiện userId không hợp lệ")
            }
            return ""
        }
        let firstInitial = participant.user.firstName?.prefix(1) ?? ""
        let lastInitial = participant.user.lastName?.prefix(1) ?? ""
        let initials = "\(firstInitial)\(lastInitial)"
        print("✅ Generated initials \(initials) for userId=\(userId) in item \(item.name)")
        return initials
    }

    func assignItem(itemId: Int, to userId: Int?) {
        guard let index = packingList.sharedItems.firstIndex(where: { $0.id == itemId }) else {
            print("❌ Item \(itemId) not found in shared items")
            showToast(message: "Không tìm thấy vật dụng")
            return
        }
        let oldUserId = packingList.sharedItems[index].userId
        if oldUserId == userId {
            print("⚠️ No change in userId for item \(itemId): \(packingList.sharedItems[index].name), already set to \(String(describing: userId))")
            return
        }
        print("🔄 Assigning shared item \(itemId): \(packingList.sharedItems[index].name) from userId=\(String(describing: oldUserId)) to userId=\(String(describing: userId))")
        packingList.sharedItems[index].userId = userId
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
            print("❌ Lỗi khi gán item \(itemId): \(error.localizedDescription)")
        }
        saveToCache(packingList: packingList)
    }

    private func handleCompletion(_ completion: Subscribers.Completion<Error>, completionHandler: (() -> Void)? = nil) {
        switch completion {
        case .failure(let error):
            print("❌ Error performing request: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("🔍 Data corrupted: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("🔍 Key '\(key)' not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("🔍 Type '\(type)' mismatch: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("🔍 Value '\(type)' not found: \(context.debugDescription)")
                @unknown default:
                    print("🔍 Unknown decoding error")
                }
            }
            showToast(message: "Lỗi khi thực hiện hành động")
        case .finished:
            print("✅ Request completed")
        }
        completionHandler?()
    }

    private func saveToCache(packingList: PackingList) {
        do {
            let data = try JSONEncoder().encode(packingList)
            UserDefaults.standard.set(data, forKey: "packing_list_cache_\(tripId)")
            print("✅ Saved packing list to cache for tripId=\(tripId)")
        } catch {
            print("❌ Error saving packing list cache: \(error.localizedDescription)")
            showToast(message: "Lỗi khi lưu cache")
        }
    }

    private func loadFromCache() -> PackingList? {
        guard let data = UserDefaults.standard.data(forKey: "packing_list_cache_\(tripId)") else {
            print("⚠️ No packing list cache found for tripId=\(tripId)")
            return nil
        }
        do {
            let packingList = try JSONDecoder().decode(PackingList.self, from: data)
            print("✅ Loaded packing list from cache for tripId=\(tripId)")
            return packingList
        } catch {
            print("❌ Error reading packing list cache: \(error.localizedDescription)")
            UserDefaults.standard.removeObject(forKey: "packing_list_cache_\(tripId)")
            return nil
        }
    }

    private func showToast(message: String) {
        print("📢 Setting toast: \(message)")
        if showToast {
            print("⚠️ Toast already visible, queuing: \(message)")
            return
        }
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
}
