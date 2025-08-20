import Foundation
import Combine
import Network

class TripDashboardViewModel: ObservableObject {
    @Published var dashboard: TripDashboardModel?
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var isOffline: Bool = false
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "network.monitor")
    private let networkManager = NetworkManager()
    private let tripId: Int

    init(tripId: Int) {
        self.tripId = tripId
        if tripId <= 0 {
            print("⚠️ Cảnh báo: tripId không hợp lệ (\(tripId))")
            showToast(message: "ID chuyến đi không hợp lệ.")
        }
        setupNetworkMonitor()
        if let cachedDashboard = loadFromCache() {
            self.dashboard = cachedDashboard
        } else if !isOffline && tripId > 0 {
            fetchDashboard()
        }
    }

    func fetchDashboard(completion: (() -> Void)? = nil) {
        if tripId <= 0 {
            print("❌ Không thể fetch dashboard: tripId không hợp lệ (\(tripId))")
            showToast(message: "ID chuyến đi không hợp lệ.")
            isLoading = false
            completion?()
            return
        }

        if let cachedDashboard = loadFromCache() {
            self.dashboard = cachedDashboard
            completion?()
            if isOffline {
                print("Ứng dụng đang offline, sử dụng cache")
                return
            }
        }

        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/dashboard") else {
            print("❌ URL không hợp lệ: \(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/dashboard")
            showToast(message: "URL không hợp lệ. Vui lòng kiểm tra cấu hình.")
            isLoading = false
            completion?()
            return
        }

        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ Token không hợp lệ")
            showToast(message: "Không tìm thấy token xác thực.")
            isLoading = false
            completion?()
            return
        }

        print("📡 Gửi yêu cầu đến: \(url.absoluteString)")
        print("📡 Token: \(token)")

        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: TripDashboardResponse.self)
            .sink { [weak self] completionResult in
                self?.isLoading = false
                self?.handleCompletion(completionResult, completionHandler: completion)
            } receiveValue: { [weak self] response in
                guard response.success else {
                    self?.showToast(message: "Lỗi: Không lấy được dữ liệu dashboard")
                    return
                }
                let dashboardData = response.data
                let dashboard = TripDashboardModel(
                    id: self?.tripId ?? -1,
                    activities: dashboardData.activityCosts,
                    totalEstimated: dashboardData.totalExpected,
                    totalActual: dashboardData.totalActual,
                    balance: dashboardData.balance
                )
                self?.dashboard = dashboard
                print("✅ Dashboard fetched for Trip ID: \(dashboard.id)")
                self?.saveToCache(dashboard: dashboard)
            }
            .store(in: &cancellables)
    }

    func refreshDashboard() {
        isRefreshing = true
        UserDefaults.standard.removeObject(forKey: "dashboard_cache_\(tripId)")
        fetchDashboard { [weak self] in
            self?.isRefreshing = false
        }
    }

    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOffline = path.status != .satisfied
                if !(self?.isOffline ?? true) && (self?.tripId ?? 0) > 0 {
                    self?.fetchDashboard()
                }
            }
        }
        networkMonitor.start(queue: queue)
    }

    private func handleCompletion(_ completion: Subscribers.Completion<Error>, completionHandler: (() -> Void)? = nil) {
        switch completion {
        case .failure(let error):
            print("❌ Lỗi: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                switch urlError.code {
                case .badServerResponse:
                    showToast(message: "Phản hồi từ server không hợp lệ (HTTP \(urlError.code.rawValue)).")
                case .notConnectedToInternet:
                    showToast(message: "Mạng yếu, đã sử dụng dữ liệu cache!")
                case .badURL:
                    showToast(message: "URL không hợp lệ. Vui lòng kiểm tra cấu hình API.")
                case .resourceUnavailable:
                    showToast(message: "Không tìm thấy dữ liệu dashboard (HTTP 404). Trip ID có thể không hợp lệ.")
                default:
                    showToast(message: "Lỗi mạng: \(error.localizedDescription)")
                }
            } else if let decodingError = error as? DecodingError {
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
                showToast(message: "Lỗi xử lý dữ liệu từ server.")
            }
        case .finished:
            print("✅ Hoàn tất thành công")
        }
        completionHandler?()
    }

    private func saveToCache(dashboard: TripDashboardModel) {
        do {
            let data = try JSONEncoder().encode(dashboard)
            UserDefaults.standard.set(data, forKey: "dashboard_cache_\(tripId)")
        } catch {
            print("❌ Lỗi khi lưu cache: \(error.localizedDescription)")
        }
    }

    private func loadFromCache() -> TripDashboardModel? {
        guard let data = UserDefaults.standard.data(forKey: "dashboard_cache_\(tripId)") else { return nil }
        do {
            return try JSONDecoder().decode(TripDashboardModel.self, from: data)
        } catch {
            print("❌ Lỗi khi đọc cache: \(error.localizedDescription)")
            return nil
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
