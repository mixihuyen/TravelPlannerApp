import Foundation
import Combine

class AuthService {
    private let networkManager = NetworkManager.shared
    @Published var toastMessage: String?
    @Published var showToast: Bool = false
    @Published var toastType: ToastType?
    private var cancellables = Set<AnyCancellable>()
    
    private var isRefreshingToken = false // Biến kiểm soát trạng thái refresh token

        func refreshToken() -> AnyPublisher<RefreshTokenResponse, Error> {
            // Kiểm tra nếu đang refresh token thì không gọi lại
            guard !isRefreshingToken else {
                print("🔄 Refresh token already in progress, skipping")
                return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Đang làm mới token, bỏ qua yêu cầu."])).eraseToAnyPublisher()
            }

            isRefreshingToken = true // Đánh dấu đang refresh
            print("🔄 Starting token refresh")

            // 1. Lấy refresh token từ UserDefaults
            guard let refreshToken = UserDefaults.standard.string(forKey: "refreshToken") else {
                isRefreshingToken = false
                DispatchQueue.main.async {
                    print("🔔 Sending showAuthErrorAlert notification for missing refresh token")
                    NotificationCenter.default.post(name: .showAuthErrorAlert, object: nil, userInfo: [
                        "title": "Phiên Đăng Nhập Hết Hạn",
                        "message": "Phiên đăng nhập của bạn đã hết hạn. Vui lòng đăng nhập lại."
                    ])
                }
                return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy refresh token."])).eraseToAnyPublisher()
            }
            
            print("🔍 Current refreshToken: \(refreshToken)")
            
            // 2. Tạo URL cho endpoint
            guard let url = URL(string: "\(APIConfig.baseURL)/auth/handle-refresh-token") else {
                isRefreshingToken = false
                DispatchQueue.main.async {
                    print("🔔 Sending showAuthErrorAlert notification for invalid URL")
                    NotificationCenter.default.post(name: .showAuthErrorAlert, object: nil, userInfo: [
                        "title": "Lỗi Kết Nối",
                        "message": "Có lỗi xảy ra khi kết nối với máy chủ. Vui lòng thử lại sau."
                    ])
                }
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            
            // 3. Tạo request
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // 4. Tạo body chứa refresh token
            let body: [String: Any] = ["refreshToken": refreshToken]
            do {
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
                if let jsonString = String(data: urlRequest.httpBody!, encoding: .utf8) {
                    print("📤 Request body for refreshToken: \(jsonString)")
                }
            } catch {
                isRefreshingToken = false
                DispatchQueue.main.async {
                    print("🔔 Sending showAuthErrorAlert notification for JSON encoding error")
                    NotificationCenter.default.post(name: .showAuthErrorAlert, object: nil, userInfo: [
                        "title": "Lỗi Kết Nối",
                        "message": "Có lỗi khi xử lý yêu cầu. Vui lòng thử lại sau."
                    ])
                }
                return Fail(error: error).eraseToAnyPublisher()
            }
            
            // 5. Gửi request và xử lý phản hồi
            return networkManager.performRequest(urlRequest, decodeTo: RefreshTokenResponse.self)
                .handleEvents(receiveCompletion: { [weak self] _ in
                    self?.isRefreshingToken = false // Reset trạng thái sau khi hoàn thành
                    print("🔄 Finished token refresh")
                })
                .catch { [weak self] error -> AnyPublisher<RefreshTokenResponse, Error> in
                    self?.isRefreshingToken = false
                    if let urlError = error as? URLError,
                       urlError.code == .cannotDecodeContentData,
                       let statusCode = urlError.userInfo["HTTPStatusCode"] as? Int,
                       (statusCode == 400 || statusCode == 401 || statusCode == 403 || statusCode == 500) {
                        DispatchQueue.main.async {
                            print("🔔 Sending showAuthErrorAlert notification for HTTP \(statusCode) decoding error")
                            NotificationCenter.default.post(name: .showAuthErrorAlert, object: nil, userInfo: [
                                "title": "Phiên Đăng Nhập Hết Hạn",
                                "message": "Phiên đăng nhập của bạn không hợp lệ do lỗi máy chủ. Vui lòng đăng nhập lại."
                            ])
                        }
                        return Fail(error: NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Phiên đăng nhập không hợp lệ do lỗi máy chủ."])).eraseToAnyPublisher()
                    }
                    return Fail(error: error).eraseToAnyPublisher()
                }
                .flatMap { response in
                    Future<RefreshTokenResponse, Error> { promise in
                        if response.success && (200...299).contains(response.statusCode) {
                            UserDefaults.standard.set(response.data.token.accessToken, forKey: "authToken")
                            UserDefaults.standard.set(response.data.token.refreshToken, forKey: "refreshToken")
                            print("✅ Successfully refreshed token")
                            promise(.success(response))
                        } else {
                            DispatchQueue.main.async {
                                print("🔔 Sending showAuthErrorAlert notification for HTTP \(response.statusCode) error in refreshToken")
                                NotificationCenter.default.post(name: .showAuthErrorAlert, object: nil, userInfo: [
                                    "title": "Phiên Đăng Nhập Hết Hạn",
                                    "message": "Phiên đăng nhập của bạn không hợp lệ. Vui lòng đăng nhập lại."
                                ])
                            }
                            promise(.failure(NSError(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Phiên đăng nhập không hợp lệ: \(response.message)"])))
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
            DispatchQueue.main.async {
                print("🔔 Sending showAuthErrorAlert notification for missing auth token")
                NotificationCenter.default.post(name: .showAuthErrorAlert, object: nil, userInfo: [
                    "title": "Phiên Đăng Nhập Không Hợp Lệ",
                    "message": "Phiên đăng nhập của bạn không hợp lệ. Vui lòng đăng nhập lại."
                ])
                AuthManager().logout()
            }
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
                    DispatchQueue.main.async {
                        print("🔔 Sending showAuthErrorAlert notification for userAuthenticationRequired")
                        NotificationCenter.default.post(name: .showAuthErrorAlert, object: nil, userInfo: [
                            "title": "Phiên Đăng Nhập Không Hợp Lệ",
                            "message": "Phiên đăng nhập hết hạn, vui lòng đăng nhập lại!"
                        ])
                        AuthManager().logout()
                    }
                    return Fail(error: NSError(domain: "", code: URLError.userAuthenticationRequired.rawValue, userInfo: [NSLocalizedDescriptionKey: "Phiên đăng nhập hết hạn, vui lòng đăng nhập lại!"])).eraseToAnyPublisher()
                } else {
                    print("❌ Lỗi khi cập nhật profile: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        print("🔔 Sending showAuthErrorAlert notification for profile update error")
                        NotificationCenter.default.post(name: .showAuthErrorAlert, object: nil, userInfo: [
                            "title": "Lỗi Kết Nối",
                            "message": "Có lỗi khi cập nhật hồ sơ: \(error.localizedDescription)"
                        ])
                    }
                    return Fail(error: NSError(domain: "", code: (error as NSError).code, userInfo: [NSLocalizedDescriptionKey: "Tên người dùng đã được sử dụng, vui lòng chọn tên khác!"])).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
}
