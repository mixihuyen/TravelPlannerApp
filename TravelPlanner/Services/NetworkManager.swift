import Foundation
import Combine
import Network

class NetworkManager {
    private let session: URLSession
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    @Published private(set) var isNetworkAvailable: Bool = true
    private var cancellables = Set<AnyCancellable>()

    init(timeoutInterval: TimeInterval = APIConfig.timeoutInterval) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = max(timeoutInterval, 30.0) 
        config.timeoutIntervalForResource = 60.0
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        
        // Khởi tạo NWPathMonitor để theo dõi trạng thái mạng
        self.monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            DispatchQueue.main.async {
                if self?.isNetworkAvailable != isConnected {
                    self?.isNetworkAvailable = isConnected
                    print("🌐 Network status changed: \(isConnected ? "Connected" : "Disconnected")")
                }
            }
        }
        monitor.start(queue: queue)
    }

    func performRequest<T: Decodable>(_ request: URLRequest, decodeTo type: T.Type) -> AnyPublisher<T, Error> {
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
                        if (400..<600).contains(httpResponse.statusCode) {
                            print("🌐 HTTP Status Code \(httpResponse.statusCode), but decoded response: \(String(data: result.data, encoding: .utf8) ?? "Unable to convert data")")
                            return decodedResponse
                        }
                        return decodedResponse
                    } catch {
                        print("❌ Decoding error: \(error.localizedDescription)")
                        throw URLError(.cannotDecodeContentData, userInfo: ["HTTPStatusCode": httpResponse.statusCode, "UnderlyingError": error])
                    }
                }
                .catch { error -> AnyPublisher<T, Error> in
                    if let urlError = error as? URLError,
                       urlError.code == .badServerResponse,
                       let statusCode = urlError.userInfo["HTTPStatusCode"] as? Int,
                       statusCode == 500,
                       urlError.userInfo["Retry"] as? String == "NeedsTokenRefresh" {
                        print("🔄 Attempting to refresh token due to 500 error")
                        let authService = AuthService(networkManager: self)
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
                                return Fail(error: NSError(domain: "", code: URLError.userAuthenticationRequired.rawValue, userInfo: [NSLocalizedDescriptionKey: "Phiên đăng nhập hết hạn, vui lòng đăng nhập lại!"])).eraseToAnyPublisher()
                            }
                            .eraseToAnyPublisher()
                    }
                    
                    print("❌ Request error: \(error.localizedDescription)")
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

    static func isConnected(timeout: Double = 10.0) -> Bool {
        let monitor = NWPathMonitor()
        var isConnected = false
        let semaphore = DispatchSemaphore(value: 0)
        
        monitor.pathUpdateHandler = { path in
            isConnected = path.status == .satisfied
            semaphore.signal()
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitorSync.\(UUID().uuidString)")) // UUID để tránh xung đột queue
        
        _ = semaphore.wait(timeout: .now() + timeout)
        monitor.cancel()
        
        print("🌐 Network check: \(isConnected ? "Connected" : "Disconnected")")
        return isConnected
    }

    deinit {
        monitor.cancel()
        cancellables.removeAll()
        print("🗑️ NetworkManager deallocated")
    }
}

// Struct để xử lý phản hồi rỗng
struct EmptyResponse: Decodable {
    init() {}
}
