import Foundation
import Combine

class AuthService {
    
    
    private let networkManager: NetworkManager
    @Published var toastMessage: String?
    @Published var showToast: Bool = false
    @Published var toastType: ToastType?
    private var cancellables = Set<AnyCancellable>()
    
    init(networkManager: NetworkManager = NetworkManager()) {
        self.networkManager = networkManager
    }
    
    func refreshToken() -> AnyPublisher<RefreshTokenResponse, Error> {
            guard let refreshToken = UserDefaults.standard.string(forKey: "refreshToken") else {
                return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy refresh token."])).eraseToAnyPublisher()
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)/auth/handle-refresh-token") else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = ["refreshToken": refreshToken]
            do {
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                return Fail(error: error).eraseToAnyPublisher()
            }
            
            return networkManager.performRequest(urlRequest, decodeTo: RefreshTokenResponse.self)
                .flatMap { response in
                    Future<RefreshTokenResponse, Error> { promise in
                        if response.success && (200...299).contains(response.statusCode) {
                            UserDefaults.standard.set(response.data.token.accessToken, forKey: "authToken")
                            UserDefaults.standard.set(response.data.token.refreshToken, forKey: "refreshToken")
                            promise(.success(response))
                        } else {
                            promise(.failure(NSError(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: response.message])))
                        }
                    }
                }
                .eraseToAnyPublisher()
        }
    
    static func sendOTPRequest(to email: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(APIConfig.baseURL)/auth/email-send-otp") else {
            completion(false, "URL không hợp lệ.")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["email": email]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(false, "Lỗi mã hóa dữ liệu: \(error.localizedDescription)")
            return
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true
        
        let session = URLSession(configuration: config)
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Lỗi kết nối: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                    completion(false, "Không có phản hồi từ server.")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let success = json["success"] as? Bool ?? false
                        let message = json["message"] as? String ?? "Phản hồi không hợp lệ từ server."
                        completion(success, success ? nil : message)
                    } else {
                        completion(false, "Phản hồi không hợp lệ.")
                    }
                } catch {
                    completion(false, "Lỗi phân tích phản hồi: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    func verifyOTP(request: [String: String]) -> AnyPublisher<VerifyOTPResponse, Error> {
        guard let url = URL(string: "\(APIConfig.baseURL)/auth/email-verify-otp") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: request)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return networkManager.performRequest(urlRequest, decodeTo: VerifyOTPResponse.self)
    }

    func updateUserProfile(firstName: String?, lastName: String?, username: String?) -> AnyPublisher<UpdateProfileResponse, Error> {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ Không tìm thấy token xác thực trong UserDefaults")
            return Fail(error: URLError(.userAuthenticationRequired)).eraseToAnyPublisher()
        }

        guard let url = URL(string: "\(APIConfig.baseURL)/users/me") else {
            print("❌ URL không hợp lệ: \(APIConfig.baseURL)/users/me")
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        var body: [String: Any] = [:]
        if let firstName = firstName { body["first_name"] = firstName }
        if let lastName = lastName { body["last_name"] = lastName }
        if let username = username { body["username"] = username }

        guard let requestBody = try? JSONSerialization.data(withJSONObject: body) else {
            print("❌ JSON Encoding Error")
            return Fail(error: URLError(.cannotParseResponse)).eraseToAnyPublisher()
        }

        print("📤 Request body: \(String(data: requestBody, encoding: .utf8) ?? "Không thể decode body")")
        let request = NetworkManager.createRequest(url: url, method: "PATCH", token: token, body: requestBody)

        return networkManager.performRequest(request, decodeTo: UpdateProfileResponse.self)
            .flatMap { response in
                Future<UpdateProfileResponse, Error> { promise in
                    if response.success && (200...299).contains(response.statusCode) {
                        print("✅ Cập nhật profile thành công")
                        promise(.success(response))
                    } else if response.statusCode == 400 {
                        print("❌ Cập nhật profile thất bại: [\(response.statusCode)] \(response.message)")
                        promise(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Tên người dùng đã được sử dụng, vui lòng chọn tên khác!"])))
                    } else {
                        print("❌ Cập nhật profile thất bại: [\(response.statusCode)] \(response.message)")
                        promise(.failure(NSError(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: response.message.isEmpty ? "Không thể cập nhật hồ sơ, vui lòng thử lại sau!" : response.message])))
                    }
                }
            }
            .catch { error -> AnyPublisher<UpdateProfileResponse, Error> in
                if (error as? URLError)?.code == .userAuthenticationRequired {
                    print("❌ Token không hợp lệ hoặc hết hạn từ server")
                    return Fail(error: NSError(domain: "", code: URLError.userAuthenticationRequired.rawValue, userInfo: [NSLocalizedDescriptionKey: "Phiên đăng nhập hết hạn, vui lòng đăng nhập lại!"])).eraseToAnyPublisher()
                } else {
                    print("❌ Lỗi khi cập nhật profile: \(error.localizedDescription)")
                    return Fail(error: NSError(domain: "", code: (error as NSError).code, userInfo: [NSLocalizedDescriptionKey: "Tên người dùng đã được sử dụng, vui lòng chọn tên khác!"])).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
}
