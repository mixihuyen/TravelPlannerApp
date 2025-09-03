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
    @Published var toastType: ToastType?
    
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
            showToast(message: "Không có dữ liệu cache và kết nối mạng, vui lòng kết nối lại!", type: .error)
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
            showToast(message: "Không có kết nối mạng, sử dụng dữ liệu cache", type: .error)
            completion?()
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            isLoading = false
            completion?()
            showToast(message: "Không tìm thấy token xác thực", type: .error)
            return
        }
        print("authToken: \(token)")
        
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
                            self.showToast(message: "Dữ liệu từ server không đầy đủ, vui lòng thử lại!", type: .error)
                        case .typeMismatch(let type, let context):
                            print("🔍 Type '\(type)' mismatch: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("🔍 Value '\(type)' not found: \(context.debugDescription)")
                        @unknown default:
                            print("🔍 Lỗi decode không xác định")
                        }
                    } else {
                        self.showToast(message: "Lỗi khi tải danh sách chuyến đi: \(error.localizedDescription)", type: ToastType.error)
                    }
                case .finished:
                    print("✅ Fetch trips hoàn tất")
                }
                completion?()
            } receiveValue: { [weak self] response in
                guard let self else { return }
                var updatedTrips = response.data
                print("📥 API response trips: \(updatedTrips.map { "ID: \($0.id), imageCoverData: \($0.imageCoverData != nil ? "Có dữ liệu (\($0.imageCoverData!.count) bytes)" : "Không có dữ liệu")" })")
                
                let dispatchGroup = DispatchGroup()
                
                for i in 0..<updatedTrips.count {
                    let tripId = updatedTrips[i].id
                    if let imageCoverData = cachedTripDict[tripId] ?? currentTripDict[tripId] {
                        updatedTrips[i].imageCoverData = imageCoverData
                        print("📸 Restored imageCoverData for trip ID: \(tripId), size: \(imageCoverData?.count) bytes")
                    } else if let url = updatedTrips[i].imageCoverUrl, !url.isEmpty {
                        dispatchGroup.enter()
                        self.downloadImageData(from: url) { data in
                            if let data = data {
                                updatedTrips[i].imageCoverData = data
                                print("📸 Downloaded imageCoverData for trip ID: \(tripId), size: \(data.count) bytes")
                            } else {
                                print("📸 Failed to download imageCoverData for trip ID: \(tripId)")
                            }
                            dispatchGroup.leave()
                        }
                    } else {
                        print("📸 No imageCoverData or imageCoverUrl for trip ID: \(tripId)")
                    }
                }
                
                dispatchGroup.notify(queue: .main) {
                    print("📋 Updated trips after downloading images: \(updatedTrips.map { "ID: \($0.id), imageCoverData: \($0.imageCoverData != nil ? "Có dữ liệu (\($0.imageCoverData!.count) bytes)" : "Không có dữ liệu")" })")
                    self.updateTrips(with: updatedTrips)
                    self.saveToCache(trips: self.trips)
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateTrips(with newTrips: [TripModel]) {
        print("📥 Dữ liệu mới từ server: \(newTrips.map { "ID: \($0.id), name: \($0.name), participants: \($0.tripParticipants?.map { "\($0.userId):\($0.role)" } ?? [])" })")
        print("📋 Dữ liệu hiện tại trong trips: \(trips.map { "ID: \($0.id), name: \($0.name), participants: \($0.tripParticipants?.map { "\($0.userId):\($0.role)" } ?? [])" })")
        
        let currentTripIds = Set(trips.map { $0.id })
        let newTripIds = Set(newTrips.map { $0.id })
        let currentUserId = UserDefaults.standard.integer(forKey: "userId")
        let currentTripDict = Dictionary(uniqueKeysWithValues: trips.map { ($0.id, ($0.imageCoverData, $0.tripParticipants)) })
        
        var updatedTrips: [TripModel] = []
        
        for var newTrip in newTrips {
            if let (imageCoverData, existingParticipants) = currentTripDict[newTrip.id] {
                newTrip.imageCoverData = imageCoverData
                // Giữ participants cũ nếu API không trả về participants mới
                newTrip.tripParticipants = newTrip.tripParticipants ?? existingParticipants
                print("📸 Preserved imageCoverData for trip ID: \(newTrip.id), size: \(imageCoverData?.count ?? 0) bytes")
                print("👥 Preserved participants for trip ID: \(newTrip.id): \(newTrip.tripParticipants?.map { "\($0.userId):\($0.role)" } ?? [])")
            }
            if currentTripIds.contains(newTrip.id) {
                print("🔄 Cập nhật trip ID: \(newTrip.id), name: \(newTrip.name)")
                showToast(message: "Cập nhật chuyến đi: \(newTrip.name)", type: ToastType.success)
            } else {
                print("➕ Thêm trip mới ID: \(newTrip.id), name: \(newTrip.name)")
                if newTrip.createdByUserId == currentUserId {
                    showToast(message: "Thêm chuyến đi mới: \(newTrip.name)", type: ToastType.success)
                } else {
                    print("ℹ️ Chuyến đi \(newTrip.name) được thêm bởi người dùng khác (ID: \(newTrip.createdByUserId))")
                }
            }
            updatedTrips.append(newTrip)
        }
        
        self.trips = updatedTrips.sorted { $0.id < $1.id }
        self.objectWillChange.send() // Ép SwiftUI nhận ra thay đổi
        saveToCache(trips: self.trips)
    }
    
    func addTrip(name: String, description: String?, startDate: String, endDate: String, address: String?, imageCoverUrl: String?, imageCoverData: Data?) {
        // Kiểm tra kết nối mạng
        if isOffline {
            showToast(message: "Không có kết nối mạng, không thể tạo chuyến đi mới. Vui lòng kết nối mạng!", type: .error)
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            showToast(message: "Không tìm thấy token xác thực", type: ToastType.error)
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
            showToast(message: "Lỗi mã hóa dữ liệu", type: ToastType.error)
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
                    showToast(message: "Lỗi khi thêm chuyến đi: \(error.localizedDescription)", type: .error)
                case .finished:
                    self.fetchTrips(forceRefresh: true) {
                        self.showToast(message: "Thêm chuyến đi thành công!", type: ToastType.success)
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
            showToast(message: "Không có kết nối mạng, vui lòng thử lại khi có mạng!", type: ToastType.error)
            completion(false)
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            showToast(message: "Không tìm thấy token xác thực", type: ToastType.error)
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
            showToast(message: "Lỗi mã hóa dữ liệu", type: ToastType.error)
            completion(false)
            return
        }
        
        print("📤 Request body: \(String(data: body, encoding: .utf8) ?? "Không thể decode body")")
        
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
                        self.showToast(message: "Mạng yếu, vui lòng thử lại sau!", type: ToastType.error)
                    } else {
                        self.showToast(message: "Lỗi khi cập nhật chuyến đi: \(error.localizedDescription)", type: ToastType.error)
                    }
                    completion(false)
                case .finished:
                    print("✅ Cập nhật chuyến đi thành công")
                    self.fetchTrips(forceRefresh: true) {
                        self.showToast(message: "Cập nhật chuyến đi thành công!", type: ToastType.success)
                        completion(true)
                        NotificationCenter.default.post(
                            name: NSNotification.Name("TripUpdated"),
                            object: nil,
                            userInfo: ["tripId": tripId]
                        )
                    }
                }
            } receiveValue: { [weak self] response in
                guard let self else {
                    completion(false)
                    return
                }
                var updatedTrip = response.data
                updatedTrip.imageCoverData = imageCoverData
                print("🔍 Dữ liệu từ server: startDate: \(updatedTrip.startDate), endDate: \(updatedTrip.endDate), participants: \(updatedTrip.tripParticipants?.map { "\($0.userId):\($0.role)" } ?? [])")
                self.handleTripUpdate(updatedTrip)
            }
            .store(in: &cancellables)
    }
    
    func deleteTrip(id: Int, completion: @escaping (Bool) -> Void) {
        print("📋 Danh sách trips hiện có trước khi xoá:")
        trips.forEach { print("🧳 Trip ID: \($0.id) - \($0.name)") }
        
        guard let index = trips.firstIndex(where: { $0.id == id }) else {
            print("❌ Không tìm thấy trip để xóa")
            showToast(message: "Chuyến đi không tồn tại", type: ToastType.error)
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
            showToast(message: "Không có kết nối mạng, vui lòng thử lại sau", type: ToastType.error)
            completion(false)
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(id)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            trips.insert(backupTrip, at: index)
            saveToCache(trips: trips)
            print("❌ URL hoặc Token không hợp lệ")
            showToast(message: "Lỗi xác thực, vui lòng đăng nhập lại", type: ToastType.error)
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
                    print("❌ Lỗi khi xóa trip: \(error.localizedDescription)")
                    self.trips.insert(backupTrip, at: index)
                    self.saveToCache(trips: self.trips)
                    if (error as? URLError)?.code == .badServerResponse || (error as? URLError)?.code.rawValue == -1011 {
                        self.fetchTrips(forceRefresh: true) {
                            self.showToast(message: "Chuyến đi không tồn tại hoặc đã bị xóa", type: ToastType.error)
                            completion(false)
                        }
                    } else {
                        self.showToast(message: "Lỗi khi xóa chuyến đi: \(error.localizedDescription)", type: ToastType.error)
                        completion(false)
                    }
                case .finished:
                    print("✅ Xóa trip thành công")
                    self.fetchTrips(forceRefresh: true) {
                        self.showToast(message: "Xoá chuyến đi thành công!", type: ToastType.success)
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
                self.showToast(message: "Không có kết nối mạng và không có dữ liệu cache!", type: ToastType.error)
            } else if self.trips.isEmpty {
                self.showToast(message: "Không có chuyến đi nào được tải về!", type: ToastType.error)
            } else {
                self.showToast(message: "Làm mới danh sách chuyến đi thành công!", type: ToastType.success)
            }
            print("✅ Hoàn tất refresh trips với \(self.trips.count) chuyến đi")
        }
    }
    
    func handleTripUpdate(_ trip: TripModel) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            print("🔍 Trước khi cập nhật: startDate: \(trips[index].startDate), endDate: \(trips[index].endDate)")
            trips[index] = trip
            print("🔍 Sau khi cập nhật: startDate: \(trip.startDate), endDate: \(trip.endDate)")
            saveToCache(trips: self.trips)
            print("🔄 Đã cập nhật trip ID: \(trip.id) trong danh sách")
            
            // Gửi thông báo để làm mới tripDays
            NotificationCenter.default.post(
                name: NSNotification.Name("TripUpdated"),
                object: nil,
                userInfo: ["tripId": trip.id]
            )
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
    private func downloadImageData(from urlString: String, completion: @escaping (Data?) -> Void) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid image URL: \(urlString)")
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error downloading image: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                guard let data = data, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    print("❌ Failed to download image: Invalid response")
                    completion(nil)
                    return
                }
                completion(data)
            }
        }.resume()
    }
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
            showToast(message: "Dữ liệu cache bị lỗi, đang thử tải từ server...", type: ToastType.error)
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
    
    func showToast(message: String, type: ToastType) {
            print("📢 Đặt toast: \(message) với type: \(type)")
            DispatchQueue.main.async {
                self.toastMessage = message
                self.toastType = type
                self.showToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    print("📢 Ẩn toast")
                    self.showToast = false
                    self.toastMessage = nil
                    self.toastType = nil
                }
            }
        }
    
}
