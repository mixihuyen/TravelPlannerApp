//import Foundation
//import Combine
//import CoreData
//import Network
//
//class SharedPackingListViewModel: ObservableObject {
//    @Published var sharedItems: [PackingItem] = []
//    @Published var participants: [Participant] = []
//    @Published var isLoading: Bool = false
//    @Published var toastMessage: String? = nil
//    @Published var toastType: ToastType?
//    @Published var showToast: Bool = false
//
//    private var cancellables = Set<AnyCancellable>()
//    private let networkManager = NetworkManager()
//    private let participantViewModel: ParticipantViewModel
//    private let tripId: Int
//    private let coreDataStack = CoreDataStack.shared
//    private let ttl: TimeInterval = 300 // 5 phút
//    private var cacheTimestamp: Date?
//    private var lastParticipantsHash: String?
//
//    init(tripId: Int) {
//        self.tripId = tripId
//        self.participantViewModel = ParticipantViewModel()
//        loadFromCache()
//        fetchParticipants { [weak self] in
//            self?.fetchSharedItems(forceRefresh: false)
//        }
//    }
//
//    private func isCacheExpired() -> Bool {
//        guard let ts = cacheTimestamp else { return true }
//        return Date().timeIntervalSince(ts) > ttl
//    }
//
//    private func cleanupInvalidOwners() -> Bool {
//        let validUserIds = Set(participants.map { $0.user.id })
//        var needsUpdate = false
//
//        sharedItems = sharedItems.map { item in
//            var updatedItem = item
//            if let userId = item.userId, !validUserIds.contains(userId) {
//                updatedItem.userId = nil
//                needsUpdate = true
//                updatePackingItem(itemId: item.id, name: item.name, quantity: item.quantity, isShared: true, isPacked: item.isPacked, userId: nil)
//            }
//            return updatedItem
//        }
//        return needsUpdate
//    }
//
//    func fetchSharedItems(forceRefresh: Bool = false, completion: (() -> Void)? = nil) {
//        if !forceRefresh, !sharedItems.isEmpty, let ts = cacheTimestamp, Date().timeIntervalSince(ts) < ttl {
//            completion?()
//            return
//        }
//
//        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items"),
//              let token = UserDefaults.standard.string(forKey: "authToken") else {
//            showToast(message: "URL hoặc token không hợp lệ", type: .error)
//            completion?()
//            return
//        }
//
//        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
//        isLoading = true
//        networkManager.performRequest(request, decodeTo: PackingListResponse.self)
//            .sink { [weak self] completionResult in
//                self?.isLoading = false
//                switch completionResult {
//                case .failure(let error):
//                    self?.showToast(message: "Lỗi khi tải danh sách: \(error.localizedDescription)", type: .error)
//                case .finished:
//                    print("✅ Đã tải danh sách chung")
//                }
//                completion?()
//            } receiveValue: { [weak self] response in
//                guard let self, response.success else {
//                    self?.showToast(message: "Không thể tải danh sách đồ", type: .error)
//                    return
//                }
//                let newItems = response.data.tripItems
//                    .filter { $0.isShared }
//                    .map { PackingItem(from: $0) }
//                if self.sharedItems != newItems {
//                    self.sharedItems = newItems
//                    self.saveToCache()
//                }
//                completion?()
//            }
//            .store(in: &cancellables)
//    }
//
//    func createPackingItem(name: String, quantity: Int, isPacked: Bool = false, userId: Int? = nil, completion: (() -> Void)? = nil) {
//        guard !name.isEmpty else {
//            showToast(message: "Vui lòng nhập tên vật dụng", type: .error)
//            completion?()
//            return
//        }
//
//        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items"),
//              let token = UserDefaults.standard.string(forKey: "authToken") else {
//            showToast(message: "URL hoặc token không hợp lệ", type: .error)
//            completion?()
//            return
//        }
//
//        let body = CreatePackingItemRequest(name: name, quantity: quantity, isShared: true, isPacked: isPacked, userId: userId)
//        do {
//            let bodyData = try JSONEncoder().encode(body)
//            let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: bodyData)
//            isLoading = true
//            networkManager.performRequest(request, decodeTo: CreatePackingItemResponse.self)
//                .sink { [weak self] completionResult in
//                    self?.isLoading = false
//                    switch completionResult {
//                    case .failure(let error):
//                        self?.showToast(message: "Lỗi khi tạo vật dụng: \(error.localizedDescription)", type: .error)
//                    case .finished:
//                        print("✅ Đã tạo vật dụng")
//                    }
//                    completion?()
//                } receiveValue: { [weak self] response in
//                    guard let self, response.success else {
//                        self?.showToast(message: "Không thể tạo vật dụng", type: .error)
//                        return
//                    }
//                    let newItem = PackingItem(from: response.data)
//                    self.sharedItems.append(newItem)
//                    self.saveToCache()
//                    self.showToast(message: "Đã tạo \(newItem.name)", type: .success)
//                }
//                .store(in: &cancellables)
//        } catch {
//            showToast(message: "Lỗi khi chuẩn bị dữ liệu", type: .error)
//            completion?()
//        }
//    }
//
//    func updatePackingItem(itemId: Int, name: String, quantity: Int, isShared: Bool, isPacked: Bool, userId: Int?, completion: (() -> Void)? = nil) {
//        guard !name.isEmpty else {
//            showToast(message: "Vui lòng nhập tên vật dụng", type: .error)
//            completion?()
//            return
//        }
//
//        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items/\(itemId)"),
//              let token = UserDefaults.standard.string(forKey: "authToken") else {
//            showToast(message: "URL hoặc token không hợp lệ", type: .error)
//            completion?()
//            return
//        }
//
//        if let index = sharedItems.firstIndex(where: { $0.id == itemId }) {
//            sharedItems[index] = PackingItem(id: itemId, name: name, isPacked: isPacked, isShared: true, userId: userId, quantity: quantity, note: nil)
//            saveToCache()
//        }
//
//        let body = UpdatePackingItemRequest(name: name, quantity: quantity, isShared: true, isPacked: isPacked, userId: userId)
//        do {
//            let bodyData = try JSONEncoder().encode(body)
//            let request = NetworkManager.createRequest(url: url, method: "PATCH", token: token, body: bodyData)
//            isLoading = true
//            networkManager.performRequest(request, decodeTo: UpdatePackingItemResponse.self)
//                .sink { [weak self] completionResult in
//                    self?.isLoading = false
//                    switch completionResult {
//                    case .failure(let error):
//                        self?.showToast(message: "Lỗi khi cập nhật: \(error.localizedDescription)", type: .error)
//                    case .finished:
//                        print("✅ Đã cập nhật vật dụng")
//                    }
//                    completion?()
//                } receiveValue: { [weak self] response in
//                    guard let self, response.success else {
//                        self?.showToast(message: "Không thể cập nhật vật dụng", type: .error)
//                        return
//                    }
//                    let updatedItem = PackingItem(from: response.data.updatedItem)
//                    if let index = self.sharedItems.firstIndex(where: { $0.id == itemId }) {
//                        self.sharedItems[index] = updatedItem
//                        self.saveToCache()
//                    }
//                    self.showToast(message: "Đã cập nhật \(updatedItem.name)", type: .success)
//                }
//                .store(in: &cancellables)
//        } catch {
//            showToast(message: "Lỗi khi chuẩn bị dữ liệu", type: .error)
//            completion?()
//        }
//    }
//
//    func deletePackingItem(itemId: Int, completion: (() -> Void)? = nil) {
//        guard let index = sharedItems.firstIndex(where: { $0.id == itemId }) else {
//            showToast(message: "Không tìm thấy vật dụng", type: .error)
//            completion?()
//            return
//        }
//
//        let backupItem = sharedItems.remove(at: index)
//        saveToCache()
//
//        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items/\(itemId)"),
//              let token = UserDefaults.standard.string(forKey: "authToken") else {
//            sharedItems.append(backupItem)
//            saveToCache()
//            showToast(message: "URL hoặc token không hợp lệ", type: .error)
//            completion?()
//            return
//        }
//
//        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
//        isLoading = true
//        networkManager.performRequest(request, decodeTo: DeletePackingItemResponse.self)
//            .sink { [weak self] completionResult in
//                self?.isLoading = false
//                switch completionResult {
//                case .failure(let error):
//                    self?.sharedItems.append(backupItem)
//                    self?.saveToCache()
//                    self?.showToast(message: "Lỗi khi xóa: \(error.localizedDescription)", type: .error)
//                case .finished:
//                    self?.showToast(message: "Đã xóa vật dụng", type: .success)
//                }
//                completion?()
//            } receiveValue: { _ in }
//            .store(in: &cancellables)
//    }
//
//    func fetchParticipants(completion: (() -> Void)? = nil) {
//        participantViewModel.fetchParticipants(tripId: tripId) { [weak self] in
//            guard let self else { return }
//            self.participants = self.participantViewModel.participants
//            let participantsHash = self.participants.map { "\($0.user.id):\($0.user.username)" }.joined()
//            if self.lastParticipantsHash != participantsHash {
//                self.lastParticipantsHash = participantsHash
//                if self.cleanupInvalidOwners() {
//                    self.fetchSharedItems(forceRefresh: true)
//                }
//            }
//            completion?()
//        }
//    }
//
//    func binding(for item: PackingItem) -> Binding<Bool> {
//        guard let index = sharedItems.firstIndex(where: { $0.id == item.id }) else {
//            return .constant(false)
//        }
//        return Binding(
//            get: { self.sharedItems[index].isPacked },
//            set: { newValue in
//                if self.sharedItems[index].isPacked != newValue {
//                    let oldValue = self.sharedItems[index].isPacked
//                    self.sharedItems[index].isPacked = newValue
//                    self.saveToCache()
//                    self.updatePackingItem(
//                        itemId: item.id,
//                        name: self.sharedItems[index].name,
//                        quantity: self.sharedItems[index].quantity,
//                        isShared: true,
//                        isPacked: newValue,
//                        userId: self.sharedItems[index].userId
//                    ) {
//                        print("✅ Đã cập nhật isPacked cho item \(item.id)")
//                    }
//                }
//            }
//        )
//    }
//
//    func assignItem(itemId: Int, to userId: Int?) {
//        guard let index = sharedItems.firstIndex(where: { $0.id == itemId }) else {
//            showToast(message: "Không tìm thấy vật dụng", type: .error)
//            return
//        }
//        let oldUserId = sharedItems[index].userId
//        if oldUserId == userId { return }
//        sharedItems[index].userId = userId
//        saveToCache()
//        updatePackingItem(
//            itemId: itemId,
//            name: sharedItems[index].name,
//            quantity: sharedItems[index].quantity,
//            isShared: true,
//            isPacked: sharedItems[index].isPacked,
//            userId: userId
//        ) {
//            print("✅ Đã gán userId=\(String(describing: userId)) cho item \(itemId)")
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
//            UserDefaults.standard.set(Date(), forKey: "shared_packing_list_cache_timestamp_\(tripId)")
//            self.cacheTimestamp = Date()
//        } catch {
//            print("Lỗi lưu cache: \(error.localizedDescription)")
//        }
//    }
//
//    private func loadFromCache() {
//        let context = coreDataStack.context
//        let fetchRequest: NSFetchRequest<PackingItemEntity> = PackingItemEntity.fetchRequest()
//        fetchRequest.predicate = NSPredicate(format: "tripId == %d AND isShared == YES", tripId)
//        do {
//            let entities = try context.fetch(fetchRequest)
//            sharedItems = entities.map { PackingItem(from: $0) }
//            cacheTimestamp = UserDefaults.standard.object(forKey: "shared_packing_list_cache_timestamp_\(tripId)") as? Date
//        } catch {
//            print("Lỗi đọc cache: \(error.localizedDescription)")
//        }
//    }
//
//    private func clearCoreDataCache() {
//        let context = coreDataStack.context
//        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PackingItemEntity.fetchRequest()
//        fetchRequest.predicate = NSPredicate(format: "tripId == %d AND isShared == YES", tripId)
//        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
//        do {
//            try context.execute(deleteRequest)
//            coreDataStack.saveContext()
//        } catch {
//            print("Lỗi xóa cache: \(error.localizedDescription)")
//        }
//    }
//
//    func clearCacheOnLogout() {
//        sharedItems = []
//        clearCoreDataCache()
//        UserDefaults.standard.removeObject(forKey: "shared_packing_list_cache_timestamp_\(tripId)")
//    }
//
//    func showToast(message: String, type: ToastType) {
//        DispatchQueue.main.async {
//            self.toastMessage = message
//            self.toastType = type
//            self.showToast = true
//            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
//                self.showToast = false
//                self.toastMessage = nil
//                self.toastType = nil
//            }
//        }
//    }
//
//    func initials(for user: User) -> String {
//        let first = user.firstName?.prefix(1) ?? ""
//        let last = user.lastName?.prefix(1) ?? ""
//        return "\(first)\(last)"
//    }
//}
