import Foundation
import Combine
import Network
import CoreData

class TripViewModel: ObservableObject {
    @Published var trips: [TripModel] = []
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var isOffline: Bool = false
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var pendingTrips: [TripModel] = []
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "network.monitor")
    private let networkManager = NetworkManager()
    private var webSocketManager: WebSocketManager?
    private var cacheTimestamp: Date?
    private var nextTempId: Int = -1
    private let coreDataStack = CoreDataStack.shared
    private let ttl: TimeInterval = 300 // 5 phút
    
    init() {
        setupNetworkMonitor()
        loadNextTempId()
        if let cachedTrips = loadFromCache() {
            self.trips = cachedTrips
            self.cacheTimestamp = UserDefaults.standard.object(forKey: "trips_cache_timestamp") as? Date
            print("📂 Sử dụng dữ liệu từ cache")
        } else if isOffline {
            showToast(message: "Không có dữ liệu cache và kết nối mạng, vui lòng kết nối lại!")
        }
        if !isOffline {
            fetchTrips()
        }
    }
    
    // MARK: - Public Methods
    func fetchTrips(forceRefresh: Bool = false, completion: (() -> Void)? = nil) {
        if !forceRefresh {
            if let ts = cacheTimestamp, Date().timeIntervalSince(ts) < ttl, !trips.isEmpty {
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
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            isLoading = false
            completion?()
            showToast(message: "Không tìm thấy token xác thực")
            return
        }
        print("authToken: \(token)")
        
        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: TripListResponse.self)
            .sink { [weak self] completionResult in
                self?.isLoading = false
                switch completionResult {
                case .failure(let error):
                    print("❌ Lỗi khi fetch trips: \(error.localizedDescription)")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context):
                            print("🔍 Data corrupted: \(context.debugDescription)")
                        case .keyNotFound(let key, let context):
                            print("🔍 Key '\(key)' not found: \(context.debugDescription)")
                            self?.showToast(message: "Dữ liệu từ server không đầy đủ, vui lòng thử lại!")
                        case .typeMismatch(let type, let context):
                            print("🔍 Type '\(type)' mismatch: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("🔍 Value '\(type)' not found: \(context.debugDescription)")
                        @unknown default:
                            print("🔍 Lỗi decode không xác định")
                        }
                    } else {
                        self?.showToast(message: "Lỗi khi tải danh sách chuyến đi: \(error.localizedDescription)")
                    }
                case .finished:
                    print("✅ Fetch trips hoàn tất")
                }
                completion?()
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.updateTrips(with: response.data)
                print("📋 Danh sách trips sau khi fetch:")
                self.trips.forEach { trip in
                                print("🧳 Trip ID: \(trip.id) - \(trip.name) - Address: \(trip.address ?? "N/A"), Participants: \(String(describing: trip.tripParticipants?.map { "\($0.userId):\($0.role)" }))")
                            }
                self.saveToCache(trips: self.trips)
            }
            .store(in: &cancellables)
    }
    
    private func updateTrips(with newTrips: [TripModel]) {
        let currentTripIds = Set(trips.map { $0.id })
        let newTripIds = Set(newTrips.map { $0.id })
        let currentUserId = UserDefaults.standard.integer(forKey: "userId")
        
        trips.removeAll { !newTripIds.contains($0.id) }
        
        for newTrip in newTrips {
            if let index = trips.firstIndex(where: { $0.id == newTrip.id }) {
                if newTrip.updatedAt != trips[index].updatedAt {
                    print("🔄 Cập nhật trip ID: \(newTrip.id)")
                    trips[index] = newTrip
                    showToast(message: "Cập nhật chuyến đi: \(newTrip.name)")
                }
            } else {
                print("➕ Thêm trip mới ID: \(newTrip.id)")
                trips.append(newTrip)
                if newTrip.createdByUserId == currentUserId {
                    showToast(message: "Thêm chuyến đi mới: \(newTrip.name)")
                } else {
                    print("ℹ️ Chuyến đi \(newTrip.name) được thêm bởi người dùng khác (ID: \(newTrip.createdByUserId))")
                }
            }
        }
        
        trips.sort { $0.id < $1.id }
    }
    
    func addTrip(name: String, description: String?, startDate: String, endDate: String, address: String?) {
        // Kiểm tra kết nối mạng
        if isOffline {
            showToast(message: "Không có kết nối mạng, vui lòng thử lại khi có mạng!")
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            showToast(message: "Không tìm thấy token xác thực")
            return
        }
        
        let tripData = TripRequest(
            name: name,
            description: description,
            startDate: startDate,
            endDate: endDate,
            address: address,
            imageCoverUrl: nil,
            isPublic: false,
            status: "planned",
            createdByUserId: UserDefaults.standard.integer(forKey: "userId")
        )
        
        guard let body = try? JSONEncoder().encode(tripData) else {
            print("JSON Encoding Error")
            showToast(message: "Lỗi mã hóa dữ liệu")
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: body)
        isLoading = true
        networkManager.performRequest(request, decodeTo: TripSingleResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                self.isLoading = false
                switch completionResult {
                case .failure(let error):
                    if (error as? URLError)?.code == .notConnectedToInternet {
                        showToast(message: "Mạng yếu, vui lòng thử lại sau!")
                    } else {
                        print("Lỗi khi thêm chuyến đi: \(error.localizedDescription)")
                        showToast(message: "Lỗi khi thêm chuyến đi: \(error.localizedDescription)")
                    }
                case .finished:
                    // Sau khi POST thành công, gọi API GET để lấy danh sách mới nhất
                    self.fetchTrips(forceRefresh: true) {
                        self.showToast(message: "Thêm chuyến đi thành công!")
                    }
                }
            } receiveValue: { _ in
                // Không cần xử lý response ở đây vì chúng ta sẽ gọi GET để lấy danh sách mới
            }
            .store(in: &cancellables)
    }
    
    func updateTrip(tripId: Int, name: String, description: String?, startDate: String, endDate: String, address: String?, imageCoverUrl:String?, completion: @escaping (Bool) -> Void) {
            // Kiểm tra kết nối mạng
            if isOffline {
                showToast(message: "Không có kết nối mạng, vui lòng thử lại khi có mạng!")
                completion(false)
                return
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)"),
                  let token = UserDefaults.standard.string(forKey: "authToken") else {
                showToast(message: "Không tìm thấy token xác thực")
                completion(false)
                return
            }
            
            let tripData = TripRequest(
                name: name,
                description: description,
                startDate: startDate,
                endDate: endDate,
                address: address,
                imageCoverUrl: imageCoverUrl, // Có thể lấy từ TripModel nếu cần
                isPublic: false,
                status: "planned",
                createdByUserId: UserDefaults.standard.integer(forKey: "userId")
            )
            
            guard let body = try? JSONEncoder().encode(tripData) else {
                print("JSON Encoding Error")
                showToast(message: "Lỗi mã hóa dữ liệu")
                completion(false)
                return
            }
            
            let request = NetworkManager.createRequest(url: url, method: "PATCH", token: token, body: body)
            isLoading = true
            networkManager.performRequest(request, decodeTo: TripSingleResponse.self)
                .sink { [weak self] completionResult in
                    guard let self else {
                        completion(false)
                        return
                    }
                    self.isLoading = false
                    switch completionResult {
                    case .failure(let error):
                        print("Lỗi khi cập nhật chuyến đi: \(error.localizedDescription)")
                        if (error as? URLError)?.code == .notConnectedToInternet {
                            self.showToast(message: "Mạng yếu, vui lòng thử lại sau!")
                        } else {
                            self.showToast(message: "Lỗi khi cập nhật chuyến đi: \(error.localizedDescription)")
                        }
                        completion(false)
                    case .finished:
                        print("Cập nhật chuyến đi thành công")
                    }
                } receiveValue: { [weak self] response in
                    guard let self else {
                        completion(false)
                        return
                    }
                    let updatedTrip = response.data
                    self.handleTripUpdate(updatedTrip)
                    self.showToast(message: "Cập nhật chuyến đi thành công!")
                    completion(true)
                }
                .store(in: &cancellables)
        }
    
    func deleteTrip(id: Int, completion: @escaping (Bool) -> Void) {
        print("📋 Danh sách trips hiện có trước khi xoá:")
        trips.forEach { print("🧳 Trip ID: \($0.id) - \($0.name)") }
        
        guard let index = trips.firstIndex(where: { $0.id == id }) else {
            print("Không tìm thấy trip để xóa")
            showToast(message: "Chuyến đi không tồn tại")
            completion(false)
            return
        }
        
        let backupTrip = trips[index]
        trips.remove(at: index)
        saveToCache(trips: trips)
        
        if isOffline {
            print("Không có kết nối mạng, không thể xóa")
            trips.insert(backupTrip, at: index)
            saveToCache(trips: trips)
            showToast(message: "Không có kết nối mạng, vui lòng thử lại sau")
            completion(false)
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(id)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            trips.insert(backupTrip, at: index)
            saveToCache(trips: trips)
            print("URL hoặc Token không hợp lệ")
            showToast(message: "Lỗi xác thực, vui lòng đăng nhập lại")
            completion(false)
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: VoidResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                self.isLoading = false
                switch completionResult {
                case .failure(let error):
                    print("Lỗi khi xóa trip: \(error.localizedDescription)")
                    self.trips.insert(backupTrip, at: index)
                    self.saveToCache(trips: self.trips)
                    if (error as? URLError)?.code == .badServerResponse || (error as? URLError)?.code.rawValue == -1011 {
                        // Lỗi 404 hoặc lỗi server, làm mới danh sách từ server
                        self.fetchTrips(forceRefresh: true) {
                            self.showToast(message: "Chuyến đi không tồn tại hoặc đã bị xóa")
                            completion(false)
                        }
                    } else {
                        self.showToast(message: "Lỗi khi xóa chuyến đi: \(error.localizedDescription)")
                        completion(false)
                    }
                case .finished:
                    print("Xóa trip thành công")
                    // Làm mới danh sách chuyến đi từ server
                    self.fetchTrips(forceRefresh: true) {
                        self.showToast(message: "Xoá chuyến đi thành công!")
                        completion(true)
                    }
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    func refreshTrips() {
        isRefreshing = true
        
        // Xóa cache cũ
        clearCoreDataCache() // Xóa TripEntity trong Core Data
        UserDefaults.standard.removeObject(forKey: "trips_cache_timestamp") // Xóa timestamp của cache
        cacheTimestamp = nil // Đặt lại cacheTimestamp
        trips.removeAll() // Xóa danh sách trips hiện tại trong bộ nhớ
        
        print("🗑️ Đã xóa cache và danh sách trips trước khi refresh")
        
        // Gọi fetchTrips với forceRefresh = true
        fetchTrips(forceRefresh: true) { [weak self] in
            guard let self else { return }
            self.isRefreshing = false
            if self.trips.isEmpty && self.isOffline {
                self.showToast(message: "Không có kết nối mạng và không có dữ liệu cache!")
            } else if self.trips.isEmpty {
                self.showToast(message: "Không có chuyến đi nào được tải về!")
            } else {
                self.showToast(message: "Làm mới danh sách chuyến đi thành công!")
            }
            print("✅ Hoàn tất refresh trips với \(self.trips.count) chuyến đi")
        }
    }
    
    func handleTripUpdate(_ trip: TripModel) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            saveToCache(trips: trips)
        }
    }
    
    func clearCacheOnLogout() {
        trips = []
        pendingTrips = []
        clearCoreDataCache()
        UserDefaults.standard.removeObject(forKey: "pending_trips")
        UserDefaults.standard.removeObject(forKey: "trips_cache_timestamp")
        UserDefaults.standard.removeObject(forKey: "next_temp_id")
        cacheTimestamp = nil
        nextTempId = -1
        print("🗑️ Đã xóa toàn bộ cache")
    }
    
    func checkAndFetchIfNeeded() {
        fetchTrips()
    }
    
    // MARK: - Private Methods
    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOffline = path.status != .satisfied
                if !(self?.isOffline ?? true) {
                    self?.syncPendingTrips()
                }
            }
        }
        networkMonitor.start(queue: queue)
    }
    
    private func generateTempId() -> Int {
        nextTempId -= 1
        UserDefaults.standard.set(nextTempId, forKey: "next_temp_id")
        return nextTempId
    }
    
    private func loadNextTempId() {
        nextTempId = UserDefaults.standard.integer(forKey: "next_temp_id")
        if nextTempId >= 0 {
            nextTempId = -1
        }
    }
    
    private func saveToCache(trips: [TripModel]) {
        let context = coreDataStack.context
        clearCoreDataCache()
        for trip in trips {
            let entity = trip.toEntity(context: context)
            print("Saving trip: \(trip.name), tripParticipants: \(String(describing: trip.tripParticipants))")
        }
        do {
            try context.save()
            UserDefaults.standard.set(Date(), forKey: "trips_cache_timestamp")
            self.cacheTimestamp = Date()
            print("💾 Đã lưu cache với \(trips.count) chuyến đi")
        } catch {
            print("Lỗi lưu Core Data: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] as? [NSError] {
                    for validationError in detailedErrors {
                        print("Validation error: \(validationError.localizedDescription)")
                    }
                } else {
                    print("Không tìm thấy lỗi chi tiết trong userInfo")
                }
            }
        }
    }
    private func loadFromCache() -> [TripModel]? {
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<TripEntity> = TripEntity.fetchRequest()
        do {
            let entities = try context.fetch(fetchRequest)
            let trips = entities.map { TripModel(from: $0) }
            print("Đọc cache thành công với \(trips.count) chuyến đi, entities: \(entities.count)")
            return trips.isEmpty ? nil : trips // Trả về nil nếu rỗng để fetch lại
        } catch {
            print("Lỗi khi đọc cache: \(error.localizedDescription)")
            showToast(message: "Dữ liệu cache bị lỗi, đang thử tải từ server...")
            if !isOffline {
                fetchTrips()
            }
            return nil
        }
    }
    
    private func savePendingTrips() {
        do {
            let data = try JSONEncoder().encode(pendingTrips)
            UserDefaults.standard.set(data, forKey: "pending_trips")
            print("💾 Đã lưu \(pendingTrips.count) pending trips vào UserDefaults")
        } catch {
            print("Lỗi khi lưu pending trips: \(error.localizedDescription)")
        }
    }
    
    private func loadPendingTrips() -> [TripModel] {
        guard let data = UserDefaults.standard.data(forKey: "pending_trips") else {
            print("Không tìm thấy pending trips trong UserDefaults")
            return []
        }
        do {
            let pendingTrips = try JSONDecoder().decode([TripModel].self, from: data)
            print("Đọc thành công \(pendingTrips.count) pending trips từ UserDefaults")
            return pendingTrips
        } catch {
            print("Lỗi khi đọc pending trips: \(error.localizedDescription)")
            return []
        }
    }
    
    private func clearCoreDataCache() {
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TripEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            coreDataStack.saveContext()
            print("🗑️ Đã xóa cache TripEntity")
        } catch {
            print("Lỗi xóa cache: \(error.localizedDescription)")
        }
    }
    
    private func syncPendingTrips() {
        pendingTrips = loadPendingTrips()
        guard !pendingTrips.isEmpty, !isOffline else { return }
        
        for pendingTrip in pendingTrips {
            guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)"),
                  let token = UserDefaults.standard.string(forKey: "authToken") else {
                continue
            }
            
            let tripData = TripRequest(
                name: pendingTrip.name,
                description: pendingTrip.description,
                startDate: pendingTrip.startDate,
                endDate: pendingTrip.endDate,
                address: pendingTrip.address,
                imageCoverUrl: pendingTrip.imageCoverUrl,
                isPublic: pendingTrip.isPublic,
                status: pendingTrip.status,
                createdByUserId: pendingTrip.createdByUserId
            )
            
            guard let body = try? JSONEncoder().encode(tripData) else {
                continue
            }
            
            let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: body)
            
            networkManager.performRequest(request, decodeTo: TripSingleResponse.self)
                .sink { [weak self] completionResult in
                    switch completionResult {
                    case .failure(let error):
                        print("Lỗi sync trip ID \(pendingTrip.id): \(error.localizedDescription)")
                    case .finished:
                        ()
                    }
                } receiveValue: { [weak self] response in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        let realTrip = response.data
                        if let index = self.trips.firstIndex(where: { $0.id == pendingTrip.id }) {
                            self.trips[index] = realTrip
                            self.saveToCache(trips: self.trips)
                        }
                        if let pIndex = self.pendingTrips.firstIndex(where: { $0.id == pendingTrip.id }) {
                            self.pendingTrips.remove(at: pIndex)
                            self.savePendingTrips()
                        }
                        self.showToast(message: "Đã đồng bộ chuyến đi: \(realTrip.name)")
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    private func showToast(message: String) {
        print("📢 Đặt toast: \(message)")
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("📢 Ẩn toast")
            self.showToast = false
            self.toastMessage = nil
        }
    }
}
