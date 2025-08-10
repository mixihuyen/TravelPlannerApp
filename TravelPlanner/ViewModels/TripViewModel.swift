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
    private var pendingTrips: [TripModel] = []
    private var pendingDeletions: [Int] = []
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "network.monitor")
    private let networkManager = NetworkManager()
    private var webSocketManager: WebSocketManager?
    
    init() {
        UserDefaults.standard.removeObject(forKey: "trips_cache")
        setupNetworkMonitor()
        if let cachedTrips = loadFromCache() {
            self.trips = cachedTrips
        } else if !isOffline {
            fetchTrips()
        }
        
    }
    
    
    
    // MARK: - Public Methods
    func fetchTrips(completion: (() -> Void)? = nil) {
        if let cachedTrips = loadFromCache() {
            self.trips = cachedTrips
            completion?()
            if isOffline {
                print("Ứng dụng đang offline, sử dụng cache")
                return
            }
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
                    print("Lỗi khi fetch trips: \(error.localizedDescription)")
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
                    print("Fetch trips hoàn tất")
                }
                completion?()
            } receiveValue: { [weak self] response in
                self?.trips = response.data
                print("Danh sách trips sau khi fetch:")
                self?.trips.forEach { print("Trip ID: \($0.id) - \($0.name) - Address: \($0.address)") }
                self?.saveToCache(trips: self?.trips ?? [])
            }
            .store(in: &cancellables)
    }
    
    func addTrip(name: String, description: String?, startDate: String, endDate: String, address: String?) {
        let tempTrip = TripModel(
            id: -1,
            name: name,
            description: description,
            startDate: startDate,
            endDate: endDate,
            address: address ,
            imageCoverUrl: nil,
            isPublic: false,
            status: "planned",
            createdByUserId: UserDefaults.standard.integer(forKey: "userId"),
            createdAt: Date().description,
            updatedAt: Date().description,
            tripParticipants: []
        )
        
        if isOffline {
            saveTripOffline(tempTrip)
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            saveTripOffline(tempTrip)
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
            saveTripOffline(tempTrip)
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: body)
        isLoading = true
        networkManager.performRequest(request, decodeTo: TripSingleResponse.self)
            .sink { [weak self] completionResult in
                self?.isLoading = false
                self?.handleCompletion(completionResult, tempTrip: tempTrip)
            } receiveValue: { [weak self] response in
                self?.handleSuccess(response.data)
            }
            .store(in: &cancellables)
    }
    
    
    func deleteTrip(id: Int, completion: @escaping (Bool) -> Void) {
        print("📋 Danh sách trips hiện có trước khi xoá:")
        trips.forEach { print("🧳 Trip ID: \($0.id) - \($0.name)") }
        
        guard !isOffline else {
            print("Không thể xóa khi offline. Vui lòng kiểm tra kết nối mạng.")
            completion(false)
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(id)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("URL hoặc Token không hợp lệ")
            completion(false)
            return
        }
        
        
        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: VoidResponse.self)
            .sink { [weak self] completionResult in
                self?.isLoading = false
                switch completionResult {
                case .failure(let error):
                    print("Lỗi khi xóa trip: \(error.localizedDescription)")
                    completion(false)
                case .finished:
                    print("Xóa trip thành công")
                    self?.showToast(message: "Xoá chuyến đi thành công!")
                    if let index = self?.trips.firstIndex(where: { $0.id == id }) {
                        self?.trips.remove(at: index)
                        self?.saveToCache(trips: self?.trips ?? [])
                    } else {
                        print("Không tìm thấy trip trong local list sau khi xoá từ server.")
                    }
                    completion(true)
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    func refreshTrips() {
        isRefreshing = true
        UserDefaults.standard.removeObject(forKey: "trips_cache")
        fetchTrips { [weak self] in
            self?.isRefreshing = false
        }
    }
    
    func handleTripUpdate(_ trip: TripModel) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            saveToCache(trips: trips)
        }
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
    
    private func saveTripOffline(_ trip: TripModel) {
        pendingTrips.append(trip)
        trips.append(trip)
        savePendingTrips()
        saveToCache(trips: trips)
        showToast(message: "Mạng yếu, đã lưu offline!")
    }
    
    private func handleCompletion(_ completion: Subscribers.Completion<Error>, tempTrip: TripModel? = nil, completionHandler: (() -> Void)? = nil) {
        switch completion {
        case .failure(let error):
            print("Lỗi: \(error.localizedDescription)")
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
                    print("🔍 Lỗi decode không xác định")
                }
            }
            if let tempTrip = tempTrip, (error as? URLError)?.code == .notConnectedToInternet {
                saveTripOffline(tempTrip)
            }
        case .finished:
            print("Hoàn tất thành công")
        }
        completionHandler?()
    }
    
    private func handleSuccess(_ trip: TripModel) {
        trips.append(trip)
        print("Trip mới thêm có id: \(trip.id)")
        saveToCache(trips: trips)
        showToast(message: "Thêm chuyến đi thành công!")
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
            print("Không tìm thấy dữ liệu cache")
            return nil
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let trips = try decoder.decode([TripModel].self, from: data)
            print("Đọc cache thành công với \(trips.count) chuyến đi")
            return trips
        } catch {
            print("Lỗi khi đọc cache: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("🔍 Cache data corrupted: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("🔍 Cache key '\(key)' not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("🔍 Cache type '\(type)' mismatch: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("🔍 Cache value '\(type)' not found: \(context.debugDescription)")
                @unknown default:
                    print("🔍 Lỗi decode cache không xác định")
                }
            }
            // Xóa cache và thử fetch lại nếu online
            UserDefaults.standard.removeObject(forKey: "trips_cache")
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
        } catch {
            print("Lỗi khi lưu pending trips: \(error.localizedDescription)")
        }
    }
    
    private func loadPendingTrips() -> [TripModel] {
        guard let data = UserDefaults.standard.data(forKey: "pending_trips") else { return [] }
        do {
            return try JSONDecoder().decode([TripModel].self, from: data)
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
                address: trip.address
            )
        }
        pendingTrips.removeAll()
        UserDefaults.standard.removeObject(forKey: "pending_trips")
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
