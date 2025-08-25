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
        
        // Lấy dữ liệu từ Core Data và danh sách trips hiện tại để giữ imageCoverData
        let cachedTrips = loadFromCache() ?? []
        let cachedTripDict = Dictionary(uniqueKeysWithValues: cachedTrips.map { ($0.id, $0.imageCoverData) })
        let currentTripDict = Dictionary(uniqueKeysWithValues: trips.map { ($0.id, $0.imageCoverData) })
        
        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: TripListResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                self.isLoading = false
                switch completionResult {
                case .failure(let error):
                    print("❌ Lỗi khi fetch trips: \(error.localizedDescription)")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context):
                            print("🔍 Data corrupted: \(context.debugDescription)")
                        case .keyNotFound(let key, let context):
                            print("🔍 Key '\(key)' not found: \(context.debugDescription)")
                            self.showToast(message: "Dữ liệu từ server không đầy đủ, vui lòng thử lại!")
                        case .typeMismatch(let type, let context):
                            print("🔍 Type '\(type)' mismatch: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("🔍 Value '\(type)' not found: \(context.debugDescription)")
                        @unknown default:
                            print("🔍 Lỗi decode không xác định")
                        }
                    } else {
                        self.showToast(message: "Lỗi khi tải danh sách chuyến đi: \(error.localizedDescription)")
                    }
                case .finished:
                    print("✅ Fetch trips hoàn tất")
                }
                completion?()
            } receiveValue: { [weak self] response in
                guard let self else { return }
                var updatedTrips = response.data
                // Khôi phục imageCoverData từ Core Data hoặc danh sách trips hiện tại
                for i in 0..<updatedTrips.count {
                    let tripId = updatedTrips[i].id
                    if let imageCoverData = cachedTripDict[tripId] ?? currentTripDict[tripId] {
                        updatedTrips[i].imageCoverData = imageCoverData
                        print("📸 Restored imageCoverData for trip ID: \(tripId), size: bytes")
                    } else {
                        print("📸 No imageCoverData found for trip ID: \(tripId) in cache or current trips")
                    }
                }
                self.updateTrips(with: updatedTrips)
                print("📋 Danh sách trips sau khi fetch:")
                self.trips.forEach { trip in
                    print("🧳 Trip ID: \(trip.id) - \(trip.name) - Address: \(trip.address ?? "N/A"), Participants: \(String(describing: trip.tripParticipants?.map { "\($0.userId):\($0.role)" })), imageCoverData: \(trip.imageCoverData != nil ? "Có dữ liệu (\(trip.imageCoverData!.count) bytes)" : "Không có dữ liệu")")
                }
                self.saveToCache(trips: self.trips)
            }
            .store(in: &cancellables)
    }
    
    private func updateTrips(with newTrips: [TripModel]) {
            let currentTripIds = Set(trips.map { $0.id })
            let newTripIds = Set(newTrips.map { $0.id })
            let currentUserId = UserDefaults.standard.integer(forKey: "userId")
            
            // Giữ imageCoverData từ danh sách trips hiện tại
            let currentTripDict = Dictionary(uniqueKeysWithValues: trips.map { ($0.id, $0.imageCoverData) })
            
            trips.removeAll { !newTripIds.contains($0.id) }
            
            for var newTrip in newTrips {
                // Khôi phục imageCoverData từ danh sách hiện tại nếu có
                if let imageCoverData = currentTripDict[newTrip.id] {
                    newTrip.imageCoverData = imageCoverData
                    print("📸 Preserved imageCoverData for trip ID: \(newTrip.id), size:  bytes")
                }
                if let index = trips.firstIndex(where: { $0.id == newTrip.id }) {
                    // Luôn cập nhật để đảm bảo tripParticipants được cập nhật
                    print("🔄 Cập nhật trip ID: \(newTrip.id)")
                    trips[index] = newTrip
                    showToast(message: "Cập nhật chuyến đi: \(newTrip.name)")
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
    
    func addTrip(name: String, description: String?, startDate: String, endDate: String, address: String?, imageCoverUrl: String?, imageCoverData: Data?) {
        // Kiểm tra kết nối mạng
        if isOffline {
            showToast(message: "Không có kết nối mạng, không thể tạo chuyến đi mới. Vui lòng kết nối mạng!")
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
            imageCoverUrl: imageCoverUrl,
            isPublic: false,
            status: "planned",
            createdByUserId: UserDefaults.standard.integer(forKey: "userId")
        )
        
        guard let body = try? JSONEncoder().encode(tripData) else {
            print("❌ JSON Encoding Error")
            showToast(message: "Lỗi mã hóa dữ liệu")
            return
        }
        
        print("📤 Request body: \(String(data: body, encoding: .utf8) ?? "Không thể decode body")")
        let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: body)
        isLoading = true
        networkManager.performRequest(request, decodeTo: TripSingleResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                self.isLoading = false
                switch completionResult {
                case .failure(let error):
                    print("❌ Lỗi khi thêm chuyến đi: \(error.localizedDescription)")
                    showToast(message: "Lỗi khi thêm chuyến đi: \(error.localizedDescription)")
                case .finished:
                    self.fetchTrips(forceRefresh: true) {
                        self.showToast(message: "Thêm chuyến đi thành công!")
                    }
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                var newTrip = response.data
                newTrip.imageCoverData = imageCoverData // Gắn imageCoverData trước khi lưu cache
                self.trips.append(newTrip)
                self.saveToCache(trips: self.trips)
                print("➕ Thêm chuyến đi mới ID: \(newTrip.id), imageCoverData: \(newTrip.imageCoverData != nil ? "Có dữ liệu (\(newTrip.imageCoverData!.count) bytes)" : "Không có dữ liệu")")
            }
            .store(in: &cancellables)
    }
    
    func updateTrip(tripId: Int, name: String, description: String?, startDate: String, endDate: String, address: String?, imageCoverUrl: String?, imageCoverData: Data?, completion: @escaping (Bool) -> Void) {
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
            imageCoverUrl: imageCoverUrl,
            isPublic: false,
            status: "planned",
            createdByUserId: UserDefaults.standard.integer(forKey: "userId")
        )
        
        guard let body = try? JSONEncoder().encode(tripData) else {
            print("❌ JSON Encoding Error")
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
                    print("❌ Lỗi khi cập nhật chuyến đi: \(error.localizedDescription)")
                    if (error as? URLError)?.code == .notConnectedToInternet {
                        self.showToast(message: "Mạng yếu, vui lòng thử lại sau!")
                    } else {
                        self.showToast(message: "Lỗi khi cập nhật chuyến đi: \(error.localizedDescription)")
                    }
                    completion(false)
                case .finished:
                    print("✅ Cập nhật chuyến đi thành công")
                }
            } receiveValue: { [weak self] response in
                guard let self else {
                    completion(false)
                    return
                }
                var updatedTrip = response.data
                updatedTrip.imageCoverData = imageCoverData // Gắn imageCoverData trước khi lưu cache
                self.handleTripUpdate(updatedTrip)
                self.showToast(message: "Cập nhật chuyến đi thành công!")
                completion(true)
                print("🔄 Cập nhật chuyến đi ID: \(updatedTrip.id), imageCoverData: \(updatedTrip.imageCoverData != nil ? "Có dữ liệu (\(updatedTrip.imageCoverData!.count) bytes)" : "Không có dữ liệu")")
            }
            .store(in: &cancellables)
    }
    
    func deleteTrip(id: Int, completion: @escaping (Bool) -> Void) {
        print("📋 Danh sách trips hiện có trước khi xoá:")
        trips.forEach { print("🧳 Trip ID: \($0.id) - \($0.name)") }
        
        guard let index = trips.firstIndex(where: { $0.id == id }) else {
            print("❌ Không tìm thấy trip để xóa")
            showToast(message: "Chuyến đi không tồn tại")
            completion(false)
            return
        }
        
        let backupTrip = trips[index]
        trips.remove(at: index)
        saveToCache(trips: trips)
        
        if isOffline {
            print("❌ Không có kết nối mạng, không thể xóa")
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
            print("❌ URL hoặc Token không hợp lệ")
            showToast(message: "Lỗi xác thực, vui lòng đăng nhập lại")
            completion(false)
            return
        }
        
//        // Xóa ảnh trên Cloudinary nếu có
//        if let publicId = backupTrip.imageCoverUrl?.components(separatedBy: "/").last?.components(separatedBy: ".").first {
//            CloudinaryManager().deleteImage(publicId: publicId) { result in
//                switch result {
//                case .success:
//                    print("🗑️ Xóa ảnh trên Cloudinary thành công: \(publicId)")
//                case .failure(let error):
//                    print("❌ Lỗi xóa ảnh trên Cloudinary: \(error.localizedDescription)")
//                }
//            }
//        }
        
        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: VoidResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                self.isLoading = false
                switch completionResult {
                case .failure(let error):
                    print("❌ Lỗi khi xóa trip: \(error.localizedDescription)")
                    self.trips.insert(backupTrip, at: index)
                    self.saveToCache(trips: self.trips)
                    if (error as? URLError)?.code == .badServerResponse || (error as? URLError)?.code.rawValue == -1011 {
                        self.fetchTrips(forceRefresh: true) {
                            self.showToast(message: "Chuyến đi không tồn tại hoặc đã bị xóa")
                            completion(false)
                        }
                    } else {
                        self.showToast(message: "Lỗi khi xóa chuyến đi: \(error.localizedDescription)")
                        completion(false)
                    }
                case .finished:
                    print("✅ Xóa trip thành công")
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
        // Không xóa cache ngay lập tức để giữ imageCoverData
        UserDefaults.standard.removeObject(forKey: "trips_cache_timestamp")
        cacheTimestamp = nil
        trips.removeAll()
        
        print("🗑️ Đã xóa danh sách trips và timestamp trước khi refresh")
        
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
            saveToCache(trips: self.trips)
            print("🔄 Đã cập nhật trip ID: \(trip.id) trong danh sách")
        }
    }
    
    func clearCacheOnLogout() {
        trips = []
        clearCoreDataCache()
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
                let newStatus = path.status != .satisfied
                if self?.isOffline != newStatus {
                    self?.isOffline = newStatus
                    print("🌐 Network status changed: \(newStatus ? "Offline" : "Connected")")
                    if !newStatus {
                        self?.fetchTrips(forceRefresh: true)
                    }
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
            print("Saving trip: \(trip.name), imageCoverData: \(trip.imageCoverData != nil ? "Có dữ liệu (\(trip.imageCoverData!.count) bytes)" : "Không có dữ liệu ảnh")")
        }
        do {
            try context.save()
            UserDefaults.standard.set(Date(), forKey: "trips_cache_timestamp")
            self.cacheTimestamp = Date()
            print("💾 Đã lưu cache với \(trips.count) chuyến đi")
        } catch {
            print("❌ Lỗi lưu Core Data: \(error.localizedDescription)")
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
            print("📂 Đọc cache thành công với \(trips.count) chuyến đi, entities: \(entities.count)")
            for trip in trips {
                print("📸 Loaded from cache: Trip ID: \(trip.id), imageCoverData: \(trip.imageCoverData != nil ? "Có dữ liệu (\(trip.imageCoverData!.count) bytes)" : "Không có dữ liệu")")
            }
            return trips.isEmpty ? nil : trips
        } catch {
            print("❌ Lỗi khi đọc cache: \(error.localizedDescription)")
            showToast(message: "Dữ liệu cache bị lỗi, đang thử tải từ server...")
            if !isOffline {
                fetchTrips()
            }
            return nil
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
            print("❌ Lỗi xóa cache: \(error.localizedDescription)")
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
