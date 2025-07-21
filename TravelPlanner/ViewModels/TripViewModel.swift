import Foundation
import Combine
import Network

class TripViewModel: ObservableObject {
    @Published var trips: [TripModel] = []
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var isOffline: Bool = false
    
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var pendingTrips: [TripModel] = [] // Hàng đợi cho các chuyến đi offline
    private var pendingDeletions: [Int] = [] // Hàng đợi cho các chuyến đi bị xóa offline
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "network.monitor")


    init() {
        setupNetworkMonitor()
        loadFromCache()
        fetchTrips()
    }

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

    func fetchTrips(completion: (() -> Void)? = nil) {
        // Kiểm tra và sử dụng cache trước
        if let cachedTrips = loadFromCache() {
            self.trips = cachedTrips
            completion?() // Gọi completion ngay cả khi dùng cache
            if !isOffline {
                // Chỉ gọi API khi có mạng để làm mới
                guard let url = URL(string: "https://travel-api-79ct.onrender.com/api/v1/trips") else {
                    print("URL không hợp lệ")
                    isLoading = false
                    completion?()
                    return
                }

                guard let token = UserDefaults.standard.string(forKey: "authToken") else {
                    print("Không tìm thấy token trong UserDefaults")
                    isLoading = false
                    completion?()
                    return
                }

                print("✅ Token tìm thấy: \(token)")

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                isLoading = true
                let config = URLSessionConfiguration.ephemeral
                config.timeoutIntervalForRequest = 20
                config.waitsForConnectivity = true
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601 // Xử lý định dạng ngày ISO 8601

                let session = URLSession(configuration: config)
                session.dataTaskPublisher(for: request)
                    .tryMap { result -> Data in
                        guard let httpResponse = result.response as? HTTPURLResponse else {
                            throw URLError(.badServerResponse)
                        }
                        guard (200...299).contains(httpResponse.statusCode) else {
                            print("Server trả về status code: \(httpResponse.statusCode)")
                            throw URLError(.badServerResponse)
                        }
                        // In JSON thô để debug
                        if let jsonString = String(data: result.data, encoding: .utf8) {
                            print("JSON response: \(jsonString)")
                        }
                        return result.data
                    }
                    .decode(type: TripListResponse.self, decoder: decoder)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] completionResult in
                        self?.isLoading = false
                        switch completionResult {
                        case .failure(let error):
                            if let urlError = error as? URLError {
                                print("URLError khi fetch trips: \(urlError)")
                            } else if let decodingError = error as? DecodingError {
                                switch decodingError {
                                case .dataCorrupted(let context):
                                    print("Dữ liệu hỏng: \(context.debugDescription)")
                                case .keyNotFound(let key, let context):
                                    print("Thiếu key \(key): \(context.debugDescription)")
                                case .typeMismatch(let type, let context):
                                    print("Kiểu dữ liệu không khớp \(type): \(context.debugDescription)")
                                case .valueNotFound(let type, let context):
                                    print("Không tìm thấy giá trị \(type): \(context.debugDescription)")
                                @unknown default:
                                    print("Lỗi decode không xác định: \(decodingError)")
                                }
                            } else {
                                print("Lỗi khác khi fetch trips: \(error.localizedDescription)")
                            }
                            // Giữ cache cũ khi thất bại
                        case .finished:
                            print("Fetch trips thành công")
                        }
                        completion?()
                    } receiveValue: { [weak self] response in
                        guard let self = self else { return }
                        self.trips = response.data
                        self.saveToCache(trips: self.trips)
                    }
                    .store(in: &cancellables)
            } else {
                print("Ứng dụng đang offline, sử dụng cache")
            }
            return
        }

        // Nếu không có cache và có mạng, gọi API
        if !isOffline {
            guard let url = URL(string: "https://travel-api-79ct.onrender.com/api/v1/trips") else {
                print("URL không hợp lệ")
                isLoading = false
                completion?()
                return
            }

            guard let token = UserDefaults.standard.string(forKey: "authToken") else {
                print("Không tìm thấy token trong UserDefaults")
                isLoading = false
                completion?()
                return
            }

            print("✅ Token tìm thấy: \(token)")

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            isLoading = true
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 20
            config.waitsForConnectivity = true
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601 // Xử lý định dạng ngày ISO 8601

            let session = URLSession(configuration: config)
            session.dataTaskPublisher(for: request)
                .tryMap { result -> Data in
                    guard let httpResponse = result.response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    guard (200...299).contains(httpResponse.statusCode) else {
                        print("Server trả về status code: \(httpResponse.statusCode)")
                        throw URLError(.badServerResponse)
                    }
                    // In JSON thô để debug
                    if let jsonString = String(data: result.data, encoding: .utf8) {
                        print("JSON response: \(jsonString)")
                    }
                    return result.data
                }
                .decode(type: TripListResponse.self, decoder: decoder)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completionResult in
                    self?.isLoading = false
                    switch completionResult {
                    case .failure(let error):
                        if let urlError = error as? URLError {
                            print("URLError khi fetch trips: \(urlError)")
                        } else if let decodingError = error as? DecodingError {
                            switch decodingError {
                            case .dataCorrupted(let context):
                                print("Dữ liệu hỏng: \(context.debugDescription)")
                            case .keyNotFound(let key, let context):
                                print("Thiếu key \(key): \(context.debugDescription)")
                            case .typeMismatch(let type, let context):
                                print("Kiểu dữ liệu không khớp \(type): \(context.debugDescription)")
                            case .valueNotFound(let type, let context):
                                print("Không tìm thấy giá trị \(type): \(context.debugDescription)")
                            @unknown default:
                                print("Lỗi decode không xác định: \(decodingError)")
                            }
                        } else {
                            print("Lỗi khác khi fetch trips: \(error.localizedDescription)")
                        }
                    case .finished:
                        print("Fetch trips thành công")
                    }
                    completion?()
                } receiveValue: { [weak self] response in
                    guard let self = self else { return }
                    self.trips = response.data
                    print("📋 Danh sách trips sau khi fetch:")
                    for trip in self.trips {
                        print("🧳 Trip ID: \(trip.id) - \(trip.name)")
                    }
                    self.saveToCache(trips: self.trips)
                    
                }
                .store(in: &cancellables)
        } else {
            print("Ứng dụng đang offline và không có cache")
            isLoading = false
            completion?()
        }
    }

    func addTrip(name: String, description: String?, startDate: String, endDate: String, status: String) {
        let tempTrip = TripModel(
            id: -1,
            name: name,
            description: description,
            startDate: startDate,
            endDate: endDate,
            status: isOffline ? "draft" : "active",
            createdByUserId: UserDefaults.standard.integer(forKey: "userId"),
            createdAt: Date().description,
            updatedAt: Date().description,
            tripParticipants: []
        )

        if isOffline {
            pendingTrips.append(tempTrip)
            savePendingTrips()
            trips.append(tempTrip)
            saveToCache(trips: trips)
            if let cached = loadFromCache() {
                    self.trips = cached
                }
            showToast(message: "Mạng yếu, đã lưu offline!")
            return
        }

        guard let url = URL(string: "https://travel-api-79ct.onrender.com/api/v1/trips"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ URL hoặc Token không hợp lệ")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let tripData: [String: Any] = [
            "name": name,
            "description": description ?? "",
            "start_date": startDate,
            "end_date": endDate,
            "status": status,
            "created_by_user_id": UserDefaults.standard.integer(forKey: "userId")
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: tripData)
            request.httpBody = jsonData
        } catch {
            print("❌ JSON Encoding Error: \(error)")
            pendingTrips.append(tempTrip)
            savePendingTrips()
            trips.append(tempTrip)
            saveToCache(trips: trips)
            return
        }

        isLoading = true
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true

        let session = URLSession(configuration: config)
        session.dataTaskPublisher(for: request)
            .tryMap { result -> Data in
                guard let httpResponse = result.response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return result.data
            }
            .decode(type: TripSingleResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case let .failure(error) = completion {
                    print("❌ Thêm trip thất bại: \(error.localizedDescription)")
                    
                    // Decode error chi tiết
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context): print("🔍 Data corrupted: \(context.debugDescription)")
                        case .keyNotFound(let key, let context): print("🔍 Key '\(key)' not found: \(context.debugDescription)")
                        case .typeMismatch(let type, let context): print("🔍 Type '\(type)' mismatch: \(context.debugDescription)")
                        case .valueNotFound(let type, let context): print("🔍 Value '\(type)' not found: \(context.debugDescription)")
                        @unknown default: print("Lỗi decode không xác định")
                        }
                    }

                    // Nếu mất mạng
                    if (error as? URLError)?.code == .notConnectedToInternet {
                        self?.pendingTrips.append(tempTrip)
                        self?.savePendingTrips()
                        self?.trips.append(tempTrip)
                        self?.showToast(message:"Mạng yếu, đã lưu offline!")
                        self?.saveToCache(trips: self?.trips ?? [])
                    }
                }
            } receiveValue: { [weak self] response in
                let trip = response.data
                self?.trips.append(trip)
                print("✅ Trip mới thêm có id: \(trip.id)")
                self?.saveToCache(trips: self?.trips ?? [])
                self?.fetchTrips()
                self?.showToast(message: "Thêm chuyến đi thành công!")
                


            }
            .store(in: &cancellables)
    }



    func deleteTrip(id: Int, completion: @escaping (Bool) -> Void) {
        print("📋 Danh sách trips hiện có trước khi xoá:")
        for trip in trips {
            print("🧳 Trip ID: \(trip.id) - \(trip.name)")
        }

        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("Không tìm thấy token trong UserDefaults")
            completion(false)
            return
        }

        guard let url = URL(string: "https://travel-api-79ct.onrender.com/api/v1/trips/\(id)") else {
            print("URL không hợp lệ")
            completion(false)
            return
        }

        if isOffline {
            print("🚫 Không thể xóa khi offline. Vui lòng kiểm tra kết nối mạng.")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        isLoading = true
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true

        let session = URLSession(configuration: config)
        session.dataTaskPublisher(for: request)
            .tryMap { result -> Void in
                guard let httpResponse = result.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("Server trả về status code: \(httpResponse.statusCode)")
                    throw URLError(.badServerResponse)
                }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completionResult in
                self?.isLoading = false
                switch completionResult {
                case .failure(let error):
                    print("Lỗi khi xóa trip: \(error.localizedDescription)")
                    completion(false)
                case .finished:
                    print("✅ Xóa trip thành công")
                    self?.showToast(message: "Xoá chuyến đi thành công!")
                    completion(true)
                }
            } receiveValue: { [weak self] _ in
                guard let self = self else { return }
                if let index = self.trips.firstIndex(where: { $0.id == id }) {
                    self.trips.remove(at: index)
                    self.saveToCache(trips: self.trips)
                    completion(true)
                } else {
                    print("⚠️ Không tìm thấy trip trong local list sau khi xoá từ server.")
                }
            }
            .store(in: &self.cancellables)
    }



    func refreshTrips() {
        isRefreshing = true
        UserDefaults.standard.removeObject(forKey: "trips_cache")
        fetchTrips {
                self.isRefreshing = false
            }
    }

    private func saveToCache(trips: [TripModel]) {
        do {
            let data = try JSONEncoder().encode(trips)
            UserDefaults.standard.set(data, forKey: "trips_cache")
        } catch {
            print("Lỗi khi lưu cache: \(error.localizedDescription)")
        }
    }

    private func loadFromCache() -> [TripModel]? {
        guard let data = UserDefaults.standard.data(forKey: "trips_cache") else {
            return nil
        }
        
        do {
            let trips = try JSONDecoder().decode([TripModel].self, from: data)
            return trips
        } catch {
            print("Lỗi khi đọc cache: \(error.localizedDescription)")
            return nil
        }
    }

    private func savePendingTrips() {
        do {
            let data = try JSONEncoder().encode(pendingTrips)
            UserDefaults.standard.set(data, forKey: "pending_trips")
        } catch {
            print("Lỗi khi lưu pending trips: \(error.localizedDescription)")
        }
    }

    private func loadPendingTrips() -> [TripModel] {
        guard let data = UserDefaults.standard.data(forKey: "pending_trips") else {
            return []
        }
        do {
            let trips = try JSONDecoder().decode([TripModel].self, from: data)
            return trips
        } catch {
            print("Lỗi khi đọc pending trips: \(error.localizedDescription)")
            return []
        }
    }

    private func syncPendingTrips() {
        pendingTrips = loadPendingTrips()
        guard !pendingTrips.isEmpty else { return }
        
        for trip in pendingTrips {
            addTrip(
                name: trip.name,
                description: trip.description,
                startDate: trip.startDate,
                endDate: trip.endDate,
                status: trip.status
            )
        }
        pendingTrips.removeAll()
        UserDefaults.standard.removeObject(forKey: "pending_trips")
    }

    // Hàm placeholder cho WebSocket (sẽ tích hợp sau)
    func handleTripUpdate(_ trip: TripModel) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            saveToCache(trips: trips)
        }
    }
    
    func showToast(message: String) {
        print("📢 Đặt toast: \(message)")
        self.toastMessage = message
        self.showToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("📢 Ẩn toast")
            self.showToast = false
            self.toastMessage = nil
        }
    }


}
