import Foundation
import Combine
import Network

class NetworkManager {
    static let shared = NetworkManager()
    private let session: URLSession
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue.global(qos: .background)
    @Published private(set) var isNetworkAvailable: Bool = true
    private var cancellables = Set<AnyCancellable>()
    private var hasAttemptedTokenRefresh = false

    private init(timeoutInterval: TimeInterval = APIConfig.timeoutInterval) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = max(timeoutInterval, 30.0)
        config.timeoutIntervalForResource = 60.0
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        
        self.monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            DispatchQueue.main.async {
                print("🌐 NWPathMonitor update - Status: \(path.status), isConnected: \(isConnected), interface: \(path.availableInterfaces)")
                if self?.isNetworkAvailable != isConnected {
                    self?.isNetworkAvailable = isConnected
                    print("🌐 Network status changed: \(isConnected ? "Connected" : "Disconnected")")
                }
            }
        }
        monitor.start(queue: queue)
        
        checkInitialNetworkStatus()
    }
    
    private func checkInitialNetworkStatus() {
        let initialMonitor = NWPathMonitor()
        let initialQueue = DispatchQueue.global(qos: .background)
        initialMonitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            DispatchQueue.main.async {
                print("🌐 Initial network status: \(isConnected ? "Connected" : "Disconnected")")
                self?.isNetworkAvailable = isConnected
                initialMonitor.cancel()
            }
        }
        initialMonitor.start(queue: initialQueue)
    }
    
    static func isConnected(timeout: Double = 2.0) -> Bool {
        return NetworkManager.shared.isNetworkAvailable
    }
    
    deinit {
        monitor.cancel()
        print("🗑️ NetworkManager deallocated")
    }

    func performRequest<T: Decodable>(_ request: URLRequest, decodeTo type: T.Type) -> AnyPublisher<T, Error> {
            print("🛠️ Using updated NetworkManager with refreshToken for HTTP 500")
            guard isNetworkAvailable else {
                print("❌ No network connection, request aborted: \(request.url?.absoluteString ?? "unknown URL")")
                return Fail(error: URLError(.notConnectedToInternet)).eraseToAnyPublisher()
            }

            print("📤 Sending request to: \(request.url?.absoluteString ?? "unknown URL"), method: \(request.httpMethod ?? "unknown")")
            let startTime = Date()
            print("📤 Request started at: \(startTime)")
            
            return session.dataTaskPublisher(for: request)
                .tryMap { result -> T in
                    print("📥 Request completed in \(Date().timeIntervalSince(startTime)) seconds")
                    guard let httpResponse = result.response as? HTTPURLResponse else {
                        print("❌ Invalid response: No HTTP response")
                        throw URLError(.badServerResponse)
                    }
                    print("🌐 HTTP Status Code: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 204 {
                        guard type == EmptyResponse.self else {
                            print("❌ Expected EmptyResponse for 204 No Content, but got \(type)")
                            throw URLError(.badServerResponse, userInfo: ["HTTPStatusCode": httpResponse.statusCode])
                        }
                        print("✅ Received 204 No Content, no data to decode")
                        return EmptyResponse() as! T
                    }
                    
                    if result.data.isEmpty {
                        guard type == EmptyResponse.self else {
                            print("❌ Expected EmptyResponse for empty body, but got \(type)")
                            throw URLError(.dataNotAllowed, userInfo: ["HTTPStatusCode": httpResponse.statusCode])
                        }
                        print("✅ Received empty body, returning EmptyResponse")
                        return EmptyResponse() as! T
                    }

                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    do {
                        let decodedResponse = try decoder.decode(T.self, from: result.data)
                        print("✅ Successfully decoded response: \(String(data: result.data, encoding: .utf8) ?? "Unable to convert data")")
                        return decodedResponse
                    } catch {
                        print("❌ Decoding error: \(error.localizedDescription)")
                        throw URLError(.cannotDecodeContentData, userInfo: ["HTTPStatusCode": httpResponse.statusCode, "UnderlyingError": error])
                    }
                }
                .catch { [weak self] error -> AnyPublisher<T, Error> in
                    guard let self = self else {
                        return Fail(error: URLError(.badServerResponse)).eraseToAnyPublisher()
                    }
                    
                    if let urlError = error as? URLError,
                       (urlError.code == .badServerResponse || urlError.code == .cannotDecodeContentData),
                       let statusCode = urlError.userInfo["HTTPStatusCode"] as? Int,
                       (statusCode == 500 || statusCode == 401 || statusCode == 403) {
                        // Chỉ thử refresh token nếu chưa thử trước đó
                        guard !self.hasAttemptedTokenRefresh else {
                            print("🔄 Token refresh already attempted, skipping")
                            DispatchQueue.main.async {
                                print("🔔 Sending showAuthErrorAlert notification for repeated refresh attempt")
                                NotificationCenter.default.post(name: .showAuthErrorAlert, object: nil, userInfo: [
                                    "title": "Phiên Đăng Nhập Hết Hạn",
                                    "message": "Phiên đăng nhập của bạn không hợp lệ. Vui lòng đăng nhập lại."
                                ])
                            }
                            return Fail(error: NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Phiên đăng nhập không hợp lệ do lỗi máy chủ."])).eraseToAnyPublisher()
                        }
                        
                        self.hasAttemptedTokenRefresh = true
                        print("🔄 Attempting to refresh token due to HTTP \(statusCode) or decoding error")
                        let authService = AuthService()
                        return authService.refreshToken()
                            .flatMap { _ -> AnyPublisher<T, Error> in
                                var updatedRequest = request
                                if let newToken = UserDefaults.standard.string(forKey: "authToken") {
                                    updatedRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                                }
                                print("🔄 Retrying request with new token")
                                return self.performRequest(updatedRequest, decodeTo: type)
                            }
                            .catch { refreshError -> AnyPublisher<T, Error> in
                                print("❌ Failed to refresh token: \(refreshError.localizedDescription)")
                                DispatchQueue.main.async {
                                    print("🔔 Sending showAuthErrorAlert notification for failed token refresh")
                                    NotificationCenter.default.post(name: .showAuthErrorAlert, object: nil, userInfo: [
                                        "title": "Phiên Đăng Nhập Hết Hạn",
                                        "message": "Phiên đăng nhập của bạn không hợp lệ. Vui lòng đăng nhập lại."
                                    ])
                                }
                                return Fail(error: refreshError).eraseToAnyPublisher()
                            }
                            .handleEvents(receiveCompletion: { [weak self] _ in
                                self?.hasAttemptedTokenRefresh = false // Reset sau khi hoàn thành
                                print("🔄 Reset hasAttemptedTokenRefresh")
                            })
                            .eraseToAnyPublisher()
                    }
                    
                    print("❌ Request error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        print("🔔 Sending showAuthErrorAlert notification for general error")
                        NotificationCenter.default.post(name: .showAuthErrorAlert, object: nil, userInfo: [
                            "title": "Lỗi Kết Nối",
                            "message": "Có lỗi xảy ra khi tải dữ liệu. Vui lòng thử lại sau."
                        ])
                    }
                    return Fail(error: error).eraseToAnyPublisher()
                }
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        }

    static func createRequest(url: URL, method: String, token: String, body: Data? = nil) -> URLRequest {
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            if let jsonString = String(data: body, encoding: .utf8) {
                print("📤 Request body: \(jsonString)")
            }
        }
        return request
    }
}

struct EmptyResponse: Decodable {
    init() {}
}

extension NSNotification.Name {
    static let showAuthErrorAlert = Notification.Name("showAuthErrorAlert")
}
