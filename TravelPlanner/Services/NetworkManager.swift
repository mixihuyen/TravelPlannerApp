import Foundation
import Combine

class NetworkManager {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = APIConfig.timeoutInterval
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    func performRequest<T: Decodable>(_ request: URLRequest, decodeTo type: T.Type) -> AnyPublisher<T, Error> {
        session.dataTaskPublisher(for: request)
            .tryMap { result -> Data in
                guard let httpResponse = result.response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    print("Server trả về status code: \((result.response as? HTTPURLResponse)?.statusCode ?? -1)")
                    throw URLError(.badServerResponse)
                }
                if let jsonString = String(data: result.data, encoding: .utf8) {
                    print("JSON response: \(jsonString)")
                }
                return result.data
            }
            .decode(type: T.self, decoder: JSONDecoder())
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
        }
        return request
    }
}
