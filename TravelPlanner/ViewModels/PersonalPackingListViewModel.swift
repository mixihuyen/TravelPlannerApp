//import Foundation
//import Combine
//import CoreData
//import Network
//
//class PersonalPackingListViewModel: ObservableObject {
//    @Published var personalItems: [PackingItem] = []
//    @Published var isLoading: Bool = false
//    @Published var toastMessage: String? = nil
//    @Published var toastType: ToastType?
//    @Published var showToast: Bool = false
//    @Published var isOffline: Bool = false
//
//    private var cancellables = Set<AnyCancellable>()
//    private let networkManager = NetworkManager()
//    private let tripId: Int
//    private let currentUserId: Int
//    private let networkMonitor = NWPathMonitor()
//    private let queue = DispatchQueue(label: "network.monitor")
//    private let coreDataStack = CoreDataStack.shared
//    private let ttl: TimeInterval = 300 // 5 phút
//    private var cacheTimestamp: Date?
//    private var pendingItems: [PendingItem] = []
//
//    init(tripId: Int) {
//        self.tripId = tripId
//        self.currentUserId = UserDefaults.standard.integer(forKey: "userId")
//        setupNetworkMonitor()
//        loadPendingItems()
//        loadFromCache()
//        fetchPersonalItems(forceRefresh: isOffline ? false : isCacheExpired())
//    }
//
//    private func isCacheExpired() -> Bool {
//        guard let ts = cacheTimestamp else { return true }
//        return Date().timeIntervalSince(ts) > ttl
//    }
//
//    func fetchPersonalItems(forceRefresh: Bool = false, completion: (() -> Void)? = nil) {
//        if !forceRefresh, !personalItems.isEmpty, let ts = cacheTimestamp, Date().timeIntervalSince(ts) < ttl {
//            completion?()
//            return
//        }
//
//        if isOffline {
//            showToast(message: "Không có mạng, sử dụng dữ liệu cache", type: .error)
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
//                    print("✅ Đã tải danh sách cá nhân")
//                }
//                completion?()
//            } receiveValue: { [weak self] response in
//                guard let self, response.success else {
//                    self?.showToast(message: "Không thể tải danh sách đồ", type: .error)
//                    return
//                }
//                let newItems = response.data.tripItems
//                    .filter { !$0.isShared && $0.userId == self.currentUserId }
//                    .map { PackingItem(from: $0) }
//                if self.personalItems != newItems {
//                    self.personalItems = newItems
//                    self.saveToCache()
//                }
//                completion?()
//            }
//            .store(in: &cancellables)
//    }
//
//    func createPackingItem(name: String, quantity: Int, isPacked: Bool = false, completion: (() -> Void)? = nil) {
//        guard !name.isEmpty else {
//            showToast(message: "Vui lòng nhập tên vật dụng", type: .error)
//            completion?()
//            return
//        }
//
//        let tempId = generateTempId()
//        let newItem = PackingItem(id: tempId, name: name, isPacked: isPacked, isShared: false, userId: currentUserId, quantity: quantity, note: nil)
//        personalItems.append(newItem)
//        saveToCache()
//
//        if isOffline {
//            let pending = PendingItem(item: newItem, action: .create)
//            pendingItems.append(pending)
//            savePendingItems()
//            showToast(message: "Đã lưu offline", type: .success)
//            completion?()
//            return
//        }
//
//        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items"),
//              let token = UserDefaults.standard.string(forKey: "authToken") else {
//            personalItems.removeAll { $0.id == tempId }
//            saveToCache()
//            showToast(message: "URL hoặc token không hợp lệ", type: .error)
//            completion?()
//            return
//        }
//
//        let body = CreatePackingItemRequest(name: name, quantity: quantity, isShared: false, isPacked: isPacked, userId: currentUserId)
//        do {
//            let bodyData = try JSONEncoder().encode(body)
//            let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: bodyData)
//            isLoading = true
//            networkManager.performRequest(request, decodeTo: CreatePackingItemResponse.self)
//                .sink { [weak self] completionResult in
//                    self?.isLoading = false
//                    switch completionResult {
//                    case .failure(let error):
//                        self?.personalItems.removeAll { $0.id == tempId }
//                        self?.saveToCache()
//                        self?.showToast(message: "Lỗi khi tạo: \(error.localizedDescription)", type: .error)
//                    case .finished:
//                        print("✅ Đã tạo vật dụng")
//                    }
//                    completion?()
//                } receiveValue: { [weak self] response in
//                    guard let self, response.success else {
//                        self?.personalItems.removeAll { $0.id == tempId }
//                        self?.saveToCache()
//                        self?.showToast(message: "Không thể tạo vật dụng", type: .error)
//                        return
//                    }
//                    let newItem = PackingItem(from: response.data)
//                    self.replaceItem(tempId: tempId, with: newItem)
//                    self.saveToCache()
//                    self.showToast(message: "Đã tạo \(newItem.name)", type: .success)
//                }
//                .store(in: &cancellables)
//        } catch {
//            personalItems.removeAll { $0.id == tempId }
//            saveToCache()
//            showToast(message: "Lỗi khi chuẩn bị dữ liệu", type: .error)
//            completion?()
//        }
//    }
//
//    func updatePackingItem(itemId: Int, name: String, quantity: Int, isPacked: Bool, completion: (() -> Void)? = nil) {
//        guard !name.isEmpty else {
//            showToast(message: "Vui lòng nhập tên vật dụng", type: .error)
//            completion?()
//            return
//        }
//
//        if let index = personalItems.firstIndex(where: { $0.id == itemId }) {
//            personalItems[index] = PackingItem(id: itemId, name: name, isPacked: isPacked, isShared: false, userId: currentUserId, quantity: quantity, note: nil)
//            saveToCache()
//        }
//
//        if isOffline {
//            let pending = PendingItem(item: personalItems.first(where: { $0.id == itemId })!, action: .update)
//            pendingItems.append(pending)
//            savePendingItems()
//            showToast(message: "Đã lưu offline", type: .success)
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
//        let body = UpdatePackingItemRequest(name: name, quantity: quantity, isShared: false, isPacked: isPacked, userId: currentUserId)
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
//                    if let index = self.personalItems.firstIndex(where: { $0.id == itemId }) {
//                        self.personalItems[index] = updatedItem
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
//        guard let index = personalItems.firstIndex(where: { $0.id == itemId }) else {
//            showToast(message: "Không tìm thấy vật dụng", type: .error)
//            completion?()
//            return
//        }
//
//        let backupItem = personalItems.remove(at: index)
//        saveToCache()
//
//        if isOffline {
//            let pending = PendingItem(item: backupItem, action: .delete)
//            pendingItems.append(pending)
//            savePendingItems()
//            showToast(message: "Đã lưu offline", type: .success)
//            completion?()
//            return
//        }
//
//        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items/\(itemId)"),
//              let token = UserDefaults.standard.string(forKey: "authToken") else {
//            personalItems.append(backupItem)
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
//                    self?.personalItems.append(backupItem)
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
//    func binding(for item: PackingItem) -> Binding<Bool> {
//        guard let index = personalItems.firstIndex(where: { $0.id == item.id }) else {
//            return .constant(false)
//        }
//        return Binding(
//            get: { self.personalItems[index].isPacked },
//            set: { newValue in
//                if self.personalItems[index].isPacked != newValue {
//                    let oldValue = self.personalItems[index].isPacked
//                    self.personalItems[index].isPacked = newValue
//                    self.saveToCache()
//                    if self.isOffline {
//                        let pending = PendingItem(item: self.personalItems[index], action: .update)
//                        self.pendingItems.append(pending)
//                        self.savePendingItems()
//                        self.showToast(message: "Đã lưu offline", type: .success)
//                    } else {
//                        self.updatePackingItem(
//                            itemId: item.id,
//                            name: self.personalItems[index].name,
//                            quantity: self.personalItems[index].quantity,
//                            isPacked: newValue
//                        ) {
//                            print("✅ Đã cập nhật isPacked cho item \(item.id)")
//                        }
//                    }
//                }
//            }
//        )
//    }
//
//    private func saveToCache() {
//        let context = coreDataStack.context
//        clearCoreDataCache()
//        for item in personalItems {
//            _ = item.toEntity(context: context, tripId: tripId)
//        }
//        do {
//            try context.save()
//            UserDefaults.standard.set(Date(), forKey: "personal_packing_list_cache_timestamp_\(tripId)")
//            self.cacheTimestamp = Date()
//        } catch {
//            print("Lỗi lưu cache: \(error.localizedDescription)")
//        }
//    }
//
//    private func loadFromCache() {
//        let context = coreDataStack.context
//        let fetchRequest: NSFetchRequest<PackingItemEntity> = PackingItemEntity.fetchRequest()
//        fetchRequest.predicate = NSPredicate(format: "tripId == %d AND isShared == NO AND userId == %d", tripId, currentUserId)
//        do {
//            let entities = try context.fetch(fetchRequest)
//            personalItems = entities.map { PackingItem(from: $0) }
//            cacheTimestamp = UserDefaults.standard.object(forKey: "personal_packing_list_cache_timestamp_\(tripId)") as? Date
//        } catch {
//            print("Lỗi đọc cache: \(error.localizedDescription)")
//        }
//    }
//
//    private func clearCoreDataCache() {
//        let context = coreDataStack.context
//        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PackingItemEntity.fetchRequest()
//        fetchRequest.predicate = NSPredicate(format: "tripId == %d AND isShared == NO AND userId == %d", tripId, currentUserId)
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
//        personalItems = []
//        pendingItems = []
//        clearCoreDataCache()
//        UserDefaults.standard.removeObject(forKey: "pending_packing_items_\(tripId)")
//        UserDefaults.standard.removeObject(forKey: "personal_packing_list_cache_timestamp_\(tripId)")
//        UserDefaults.standard.removeObject(forKey: "next_temp_packing_id_\(tripId)")
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
//        var nextTempId = UserDefaults.standard.integer(forKey: "next_temp_packing_id_\(tripId)")
//        if nextTempId >= 0 {
//            nextTempId = -1
//        }
//        nextTempId -= 1
//        UserDefaults.standard.set(nextTempId, forKey: "next_temp_packing_id_\(tripId)")
//        return nextTempId
//    }
//
//    private func savePendingItems() {
//        do {
//            let data = try JSONEncoder().encode(pendingItems)
//            UserDefaults.standard.set(data, forKey: "pending_packing_items_\(tripId)")
//        } catch {
//            print("Lỗi lưu pending items: \(error.localizedDescription)")
//        }
//    }
//
//    private func loadPendingItems() {
//        guard let data = UserDefaults.standard.data(forKey: "pending_packing_items_\(tripId)") else { return }
//        do {
//            pendingItems = try JSONDecoder().decode([PendingItem].self, from: data)
//        } catch {
//            print("Lỗi đọc pending items: \(error.localizedDescription)")
//        }
//    }
//
//    private func syncPendingItems() {
//        guard !pendingItems.isEmpty, !isOffline else { return }
//
//        for pending in pendingItems {
//            guard let token = UserDefaults.standard.string(forKey: "authToken") else { continue }
//
//            switch pending.action {
//            case .create:
//                let body = CreatePackingItemRequest(name: pending.item.name, quantity: pending.item.quantity, isShared: false, isPacked: pending.item.isPacked, userId: currentUserId)
//                guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items"),
//                      let bodyData = try? JSONEncoder().encode(body) else { continue }
//                let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: bodyData)
//                networkManager.performRequest(request, decodeTo: CreatePackingItemResponse.self)
//                    .sink { _ in } receiveValue: { [weak self] response in
//                        if response.success {
//                            let updatedItem = PackingItem(from: response.data)
//                            self?.replaceItem(tempId: pending.item.id, with: updatedItem)
//                            self?.saveToCache()
//                            self?.removePending(with: pending.item.id)
//                            self?.showToast(message: "Đã đồng bộ tạo vật dụng", type: .success)
//                        }
//                    }
//                    .store(in: &cancellables)
//            case .update:
//                let body = UpdatePackingItemRequest(name: pending.item.name, quantity: pending.item.quantity, isShared: false, isPacked: pending.item.isPacked, userId: currentUserId)
//                guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/items/\(pending.item.id)"),
//                      let bodyData = try? JSONEncoder().encode(body) else { continue }
//                let request = NetworkManager.createRequest(url: url, method: "PATCH", token: token, body: bodyData)
//                networkManager.performRequest(request, decodeTo: UpdatePackingItemResponse.self)
//                    .sink { _ in } receiveValue: { [weak self] response in
//                        if response.success {
//                            let updatedItem = PackingItem(from: response.data.updatedItem)
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
//                networkManager.performRequest(request, decodeTo: DeletePackingItemResponse.self)
//                    .sink { _ in } receiveValue: { [weak self] response in
//                        if response.success {
//                            self?.removePending(with: pending.item.id)
//                            self?.showToast(message: "Đã đồng bộ xóa vật dụng", type: .success)
//                        }
//                    }
//                    .store(in: &cancellables)
//            }
//        }
//    }
//
//    private func removePending(with id: Int) {
//        pendingItems.removeAll { $0.item.id == id }
//        savePendingItems()
//    }
//
//    private func replaceItem(tempId: Int, with newItem: PackingItem) {
//        if let index = personalItems.firstIndex(where: { $0.id == tempId }) {
//            personalItems[index] = newItem
//        }
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
//}
