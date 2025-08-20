import Foundation
import Combine
import Network

class NetworkManager {
    private let session: URLSession
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkAvailable: Bool = true

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = APIConfig.timeoutInterval
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        
        // Khởi tạo NWPathMonitor để theo dõi trạng thái mạng
        self.monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
            print("🌐 Network status changed: \(path.status == .satisfied ? "Connected" : "Disconnected")")
        }
        monitor.start(queue: queue)
    }

    func performRequest<T: Decodable>(_ request: URLRequest, decodeTo type: T.Type) -> AnyPublisher<T, Error> {
        guard isNetworkAvailable else {
            print("❌ No network connection, request aborted: \(request.url?.absoluteString ?? "unknown URL")")
            return Fail(error: URLError(.notConnectedToInternet)).eraseToAnyPublisher()
        }

        print("📤 Sending request to: \(request.url?.absoluteString ?? "unknown URL"), method: \(request.httpMethod ?? "unknown")")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { result -> Data in
                guard let httpResponse = result.response as? HTTPURLResponse else {
                    print("❌ Invalid response: No HTTP response")
                    throw URLError(.badServerResponse)
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("❌ Server returned status code: \(httpResponse.statusCode)")
                    throw URLError(.badServerResponse, userInfo: [
                        "StatusCode": httpResponse.statusCode,
                        "ResponseData": String(data: result.data, encoding: .utf8) ?? "No data"
                    ])
                }
                if let jsonString = String(data: result.data, encoding: .utf8) {
                    //print("📥 Received JSON response: \(jsonString)")
                }
                return result.data
            }
            .decode(type: T.self, decoder: {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return decoder
            }())
            .mapError { error in
                print("❌ Request error: \(error.localizedDescription)")
                return error
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

    static func isConnected() -> Bool {
        let monitor = NWPathMonitor()
        var isConnected = false
        let semaphore = DispatchSemaphore(value: 0)
        
        monitor.pathUpdateHandler = { path in
            isConnected = path.status == .satisfied
            semaphore.signal()
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitorSync"))
        
        // Chờ tối đa 2 giây để lấy trạng thái mạng
        _ = semaphore.wait(timeout: .now() + 2)
        monitor.cancel()
        
        print("🌐 Network check: \(isConnected ? "Connected" : "Disconnected")")
        return isConnected
    }

    deinit {
        monitor.cancel()
        print("🗑️ NetworkManager deallocated")
    }
}
