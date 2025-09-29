import Foundation
import Combine
import CoreData

class TripViewModel: ObservableObject {
    @Published var trips: [TripModel] = []
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    @Published var toastType: ToastType?
    
    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager.shared
    private var cacheTimestamp: Date?
    private var nextTempId: Int = -1
    private let coreDataStack = CoreDataStack.shared
    private let ttl: TimeInterval = 300 // 5 phút
    private let imageViewModel = ImageViewModel()
    
    init() {
                loadNextTempId()
                if let cachedTrips = loadFromCache() {
                    self.trips = cachedTrips
                    self.cacheTimestamp = UserDefaults.standard.object(forKey: "trips_cache_timestamp") as? Date
                    print("📂 Sử dụng dữ liệu từ cache")
                } else if !NetworkManager.isConnected() {
                    showToast(message: "Không có dữ liệu cache và không có kết nối mạng, vui lòng kết nối lại!", type: .error)
                }
                
                // Theo dõi trạng thái mạng
                networkManager.$isNetworkAvailable
                    .sink { [weak self] isConnected in
                        guard let self else { return }
                        print("🌐 Network status in TripViewModel: \(isConnected ? "Connected" : "Disconnected")")
                        if isConnected {
                            // Gọi fetchTrips khi mạng được khôi phục
                            self.fetchTrips()
                        }
                    }
                    .store(in: &cancellables)
                
                // Gọi fetchTrips ban đầu nếu có mạng
                if NetworkManager.isConnected() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.fetchTrips()
                    }
                }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLeaveTrip),
            name: .didLeaveTrip,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLogout),
            name: .didLogout,
            object: nil
        )
    }
    
    @objc private func handleLeaveTrip() {
        fetchTrips()
    }
    
    @objc private func handleLogout() {
        clearCacheOnLogout()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .didLogout, object: nil)
        NotificationCenter.default.removeObserver(self, name: .didLeaveTrip, object: nil)
        print("🗑️ TripViewModel deallocated")
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
        
        if !NetworkManager.isConnected() {
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
                        self.showToast(message: "Lỗi khi tải danh sách chuyến đi: \(error.localizedDescription)", type: .error)
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
                    } else if let coverImageInfo = updatedTrips[i].coverImageInfo, !coverImageInfo.url.isEmpty {
                        dispatchGroup.enter()
                        self.downloadImageData(from: coverImageInfo.url) { data in
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
        let currentTripIds = Set(trips.map { $0.id })
        let currentUserId = UserDefaults.standard.integer(forKey: "userId")
        let currentTripDict = Dictionary(uniqueKeysWithValues: trips.map { ($0.id, ($0.imageCoverData, $0.tripParticipants)) })
        
        var updatedTrips: [TripModel] = []
        
        for var newTrip in newTrips {
            if let (imageCoverData, existingParticipants) = currentTripDict[newTrip.id] {
                newTrip.imageCoverData = imageCoverData
                newTrip.tripParticipants = newTrip.tripParticipants ?? existingParticipants
            }
            updatedTrips.append(newTrip)
        }
        
        self.trips = updatedTrips.sorted { $0.id < $1.id }
        self.objectWillChange.send()
        saveToCache(trips: self.trips)
    }
    
    func addTrip(name: String, description: String?, startDate: String, endDate: String, address: String?, coverImage: Int?, imageCoverData: Data?, isPublic: Bool) {
        if !NetworkManager.isConnected() {
            showToast(message: "Không có kết nối mạng, không thể tạo chuyến đi mới. Vui lòng kết nối mạng!", type: .error)
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            showToast(message: "Không tìm thấy token xác thực", type: .error)
            return
        }
        
        let tripData = TripRequest(
            name: name,
            description: description,
            startDate: startDate,
            endDate: endDate,
            address: address,
            coverImage: coverImage,
            isPublic: isPublic
        )
        
        guard let body = try? JSONEncoder().encode(tripData) else {
            print("❌ JSON Encoding Error")
            showToast(message: "Lỗi mã hóa dữ liệu", type: .error)
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
                        self.showToast(message: "Thêm chuyến đi thành công!", type: .success)
                    }
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                var newTrip = response.data
                newTrip.imageCoverData = imageCoverData
                self.trips.append(newTrip)
                self.saveToCache(trips: self.trips)
                print("➕ Thêm chuyến đi mới ID: \(newTrip.id), cover_image: \(newTrip.coverImage ?? -1), imageCoverData: \(newTrip.imageCoverData != nil ? "Có dữ liệu (\(newTrip.imageCoverData!.count) bytes)" : "Không có dữ liệu")")
            }
            .store(in: &cancellables)
    }
    
    func updateTrip(tripId: Int, name: String, description: String?, startDate: String, endDate: String, address: String?, imageCoverData: Data?, isPublic: Bool, completion: @escaping (Bool) -> Void) {
        if !NetworkManager.isConnected() {
            showToast(message: "Không có kết nối mạng, vui lòng thử lại khi có mạng!", type: .error)
            completion(false)
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            showToast(message: "Không tìm thấy token xác thực", type: .error)
            completion(false)
            return
        }
        
        let currentTrip = trips.first { $0.id == tripId }
        
        func performUpdate(coverImage: Int?, coverImageInfo: ImageData?, imageCoverData: Data?) {
            let tripData = TripRequest(
                name: name,
                description: description,
                startDate: startDate,
                endDate: endDate,
                address: address,
                coverImage: coverImage,
                isPublic: isPublic
            )
            
            guard let body = try? JSONEncoder().encode(tripData) else {
                print("❌ Lỗi mã hóa dữ liệu TripRequest")
                showToast(message: "Lỗi mã hóa dữ liệu", type: .error)
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
                        print("❌ Lỗi khi cập nhật chuyến đi ID: \(tripId): \(error.localizedDescription)")
                        if (error as? URLError)?.code == .notConnectedToInternet {
                            self.showToast(message: "Mạng yếu, vui lòng thử lại sau!", type: .error)
                        } else {
                            self.showToast(message: "Lỗi khi cập nhật chuyến đi: \(error.localizedDescription)", type: .error)
                        }
                        completion(false)
                    case .finished:
                        print("✅ Cập nhật chuyến đi ID: \(tripId) thành công")
                        self.showToast(message: "Cập nhật chuyến đi thành công!", type: .success)
                        completion(true)
                        NotificationCenter.default.post(
                            name: NSNotification.Name("TripUpdated"),
                            object: nil,
                            userInfo: ["tripId": tripId]
                        )
                    }
                } receiveValue: { [weak self] response in
                    guard let self else {
                        completion(false)
                        return
                    }
                    var updatedTrip = response.data
                    // Giữ lại imageCoverData và coverImageInfo từ currentTrip nếu không có ảnh mới
                    updatedTrip.imageCoverData = imageCoverData ?? currentTrip?.imageCoverData
                    updatedTrip.coverImageInfo = coverImageInfo ?? currentTrip?.coverImageInfo
                    updatedTrip.tripParticipants = currentTrip?.tripParticipants ?? updatedTrip.tripParticipants
                    print("🔍 Dữ liệu từ server: ID: \(updatedTrip.id), name: \(updatedTrip.name), startDate: \(updatedTrip.startDate), endDate: \(updatedTrip.endDate), coverImage: \(updatedTrip.coverImage ?? -1), imageCoverData: \(updatedTrip.imageCoverData != nil ? "Có (\(updatedTrip.imageCoverData!.count) bytes)" : "Không"), participants: \(updatedTrip.tripParticipants?.map { "\($0.userId):\($0.role)" } ?? [])")
                    self.handleTripUpdate(updatedTrip)
                }
                .store(in: &cancellables)
        }
        
        if let imageData = imageCoverData {
            // Có ảnh mới, cần xóa ảnh cũ (nếu có) và tải ảnh mới
            if let existingCoverImage = currentTrip?.coverImage {
                imageViewModel.deleteImage(imageId: existingCoverImage) { [weak self] result in
                    guard let self else {
                        completion(false)
                        return
                    }
                    switch result {
                    case .success:
                        print("✅ Đã xóa ảnh cũ ID: \(existingCoverImage)")
                        self.imageViewModel.uploadImage(imageData) { result in
                            switch result {
                            case .success(let imageInfo):
                                print("✅ Đã tải ảnh mới ID: \(imageInfo.id)")
                                performUpdate(coverImage: imageInfo.id, coverImageInfo: imageInfo, imageCoverData: imageData)
                            case .failure(let error):
                                print("❌ Lỗi khi tải ảnh mới: \(error.localizedDescription)")
                                self.showToast(message: "Lỗi khi tải ảnh mới lên server", type: .error)
                                completion(false)
                            }
                        }
                    case .failure(let error):
                        print("❌ Lỗi khi xóa ảnh cũ ID: \(existingCoverImage): \(error.localizedDescription)")
                        self.showToast(message: "Lỗi khi xóa ảnh cũ", type: .error)
                        completion(false)
                    }
                }
            } else {
                // Không có ảnh cũ, chỉ cần tải ảnh mới
                imageViewModel.uploadImage(imageData) { [weak self] result in
                    guard let self else {
                        completion(false)
                        return
                    }
                    switch result {
                    case .success(let imageInfo):
                        print("✅ Đã tải ảnh mới ID: \(imageInfo.id)")
                        performUpdate(coverImage: imageInfo.id, coverImageInfo: imageInfo, imageCoverData: imageData)
                    case .failure(let error):
                        print("❌ Lỗi khi tải ảnh: \(error.localizedDescription)")
                        self.showToast(message: "Lỗi khi tải ảnh lên server", type: .error)
                        completion(false)
                    }
                }
            }
        } else {
            // Không có ảnh mới, giữ nguyên coverImage và coverImageInfo hiện tại
            performUpdate(coverImage: currentTrip?.coverImage, coverImageInfo: currentTrip?.coverImageInfo, imageCoverData: nil)
        }
    }
    
    func deleteTrip(id: Int, completion: @escaping (Bool) -> Void) {
        print("📋 Danh sách trips hiện có trước khi xoá:")
        trips.forEach { print("🧳 Trip ID: \($0.id) - \($0.name)") }
        
        guard let index = trips.firstIndex(where: { $0.id == id }) else {
            print("❌ Không tìm thấy trip để xóa")
            showToast(message: "Chuyến đi không tồn tại", type: .error)
            completion(false)
            return
        }
        
        let backupTrip = trips[index]
        trips.remove(at: index)
        saveToCache(trips: trips)
        
        if !NetworkManager.isConnected() {
            print("❌ Không có kết nối mạng, không thể xóa")
            trips.insert(backupTrip, at: index)
            saveToCache(trips: trips)
            showToast(message: "Không có kết nối mạng, vui lòng thử lại sau", type: .error)
            completion(false)
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(id)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            trips.insert(backupTrip, at: index)
            saveToCache(trips: trips)
            print("❌ URL hoặc Token không hợp lệ")
            showToast(message: "Lỗi xác thực, vui lòng đăng nhập lại", type: .error)
            completion(false)
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: EmptyResponse.self)
            .sink { [weak self] completionResult in
                guard let self else {
                    completion(false)
                    return
                }
                self.isLoading = false
                switch completionResult {
                case .failure(let error):
                    print("❌ Lỗi khi xóa trip: \(error.localizedDescription)")
                    self.trips.insert(backupTrip, at: index)
                    self.saveToCache(trips: self.trips)
                    self.showToast(message: "Lỗi khi xóa chuyến đi: \(error.localizedDescription)", type: .error)
                    self.fetchTrips(forceRefresh: true) {
                        if self.trips.contains(where: { $0.id == id }) {
                            print("⚠️ Chuyến đi ID: \(id) vẫn tồn tại sau khi thử xóa")
                            completion(false)
                        } else {
                            print("✅ Chuyến đi ID: \(id) đã được xóa trên server")
                            self.showToast(message: "Xóa chuyến đi thành công!", type: .success)
                            completion(true)
                        }
                    }
                case .finished:
                    print("✅ Xóa trip thành công")
                    self.fetchTrips(forceRefresh: true) {
                        self.showToast(message: "Xóa chuyến đi thành công!", type: .success)
                        completion(true)
                    }
                }
            } receiveValue: { _ in
                
            }
            .store(in: &cancellables)
    }
    
    func refreshTrips() {
        isRefreshing = true
        UserDefaults.standard.removeObject(forKey: "trips_cache_timestamp")
        cacheTimestamp = nil
        trips.removeAll()
        
        print("🗑️ Đã xóa danh sách trips và timestamp trước khi refresh")
        
        if !NetworkManager.isConnected(), let cachedTrips = loadFromCache() {
            trips = cachedTrips
            cacheTimestamp = UserDefaults.standard.object(forKey: "trips_cache_timestamp") as? Date
            isRefreshing = false
            showToast(message: "Không có mạng, đã tải dữ liệu từ cache", type: .error)
            print("📂 Đã tải lại \(trips.count) chuyến đi từ cache")
            return
        }
        
        fetchTrips(forceRefresh: true) { [weak self] in
            guard let self else { return }
            self.isRefreshing = false
            if self.trips.isEmpty && !NetworkManager.isConnected() {
                self.showToast(message: "Không có kết nối mạng và không có dữ liệu cache!", type: .error)
            } else {
                self.showToast(message: "Làm mới danh sách chuyến đi thành công!", type: .success)
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
        cacheTimestamp = nil
        nextTempId = -1
        print("🗑️ Đã xóa cache của TripViewModel")
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
            print("💾 Saving trip: \(trip.name), imageCoverData: \(trip.imageCoverData != nil ? "Có dữ liệu (\(trip.imageCoverData!.count) bytes)" : "Không có dữ liệu")")
        }
        do {
            try context.save()
            CacheManager.shared.saveCacheTimestamp(forKey: "trips_cache_timestamp")
            self.cacheTimestamp = Date()
            print("💾 Đã lưu cache với \(trips.count) chuyến đi")
        } catch {
            print("❌ Lỗi lưu Core Data: \(error.localizedDescription)")
            if let nsError = error as? NSError {
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
            self.cacheTimestamp = CacheManager.shared.loadCacheTimestamp(forKey: "trips_cache_timestamp")
            return trips.isEmpty ? nil : trips
        } catch {
            print("❌ Lỗi khi đọc cache: \(error.localizedDescription)")
            showToast(message: "Dữ liệu cache bị lỗi, đang thử tải từ server...", type: .error)
            if NetworkManager.isConnected() {
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
