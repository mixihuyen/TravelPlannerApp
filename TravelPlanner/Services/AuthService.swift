import Foundation

class AuthService {
    private static func decodeUserId(from token: String) -> Int? {
            let components = token.split(separator: ".")
            guard components.count == 3 else {
                print("Invalid JWT format")
                return nil
            }
            let payload = String(components[1])
            // Đảm bảo padding đúng cho base64
            let paddedPayload = payload.padding(toLength: ((payload.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
            if let data = Data(base64Encoded: paddedPayload),
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                // Thử lấy userId từ các trường phổ biến: sub, userId, id
                return json["sub"] as? Int ?? json["userId"] as? Int ?? json["id"] as? Int
            }
            print("Failed to decode JWT payload")
            return nil
        }
    
    // Hàm gửi OTP
    static func sendOTPRequest(to email: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "https://travel-api-79ct.onrender.com/api/v1/auth/email-send-otp") else {
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
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "Không có phản hồi từ server.")
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode), let data = data else {
                    completion(false, "Lỗi server: \(httpResponse.statusCode)")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let success = json["success"] as? Bool ?? false
                        let message = json["message"] as? String
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
    
    // ✅ Hàm xác thực OTP
    static func verifyOTP(email: String, code: String, completion: @escaping (_ success: Bool, _ message: String, _ token: String?, _ firstName: String?, _ lastName: String?, _ username: String?, _ userId: Int?, _ shouldGoToHome: Bool) -> Void) {
            guard let url = URL(string: "https://travel-api-79ct.onrender.com/api/v1/auth/email-verify-otp") else {
                completion(false, "URL xác thực OTP không hợp lệ.", nil, nil, nil, nil, nil, false)
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "email": email,
                "otp": code
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(false, "Lỗi mã hóa dữ liệu OTP: \(error.localizedDescription)", nil, nil, nil, nil, nil, false)
                return
            }
            
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 20
            config.waitsForConnectivity = true
            let session = URLSession(configuration: config)
            
            session.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, "Lỗi kết nối: \(error.localizedDescription)", nil, nil, nil, nil, nil, false)
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        completion(false, "Không có phản hồi từ server.", nil, nil, nil, nil, nil, false)
                        return
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode), let data = data else {
                        completion(false, "Xác thực OTP thất bại. Mã lỗi: \(httpResponse.statusCode)", nil, nil, nil, nil, nil, false)
                        return
                    }
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("API Response: \(json)") // Debug để kiểm tra phản hồi
                            let success = json["success"] as? Bool ?? false
                            let message = json["message"] as? String ?? "Không có thông báo"
                            
                            if let dataDict = json["data"] as? [String: Any] {
                                let token = dataDict["token"] as? String
                                let user = dataDict["user"] as? [String: Any]
                                let firstName = user?["first_name"] as? String
                                let lastName = user?["last_name"] as? String
                                let username = user?["username"] as? String
                                // Thử lấy userId từ user, nếu không có thì giải mã từ token
                                let userId = (user?["id"] as? Int) ?? (token != nil ? decodeUserId(from: token!) : nil)
                                let shouldGoToHome = (username != nil && !(username?.isEmpty ?? true))
                                
                                if success {
                                    completion(true, message, token, firstName, lastName, username, userId, shouldGoToHome)
                                    print("Token: \(token ?? "Không nhận được token"), UserID: \(userId ?? 0)")
                                } else {
                                    completion(false, message, nil, nil, nil, nil, nil, false)
                                }
                            } else {
                                completion(false, "Phản hồi không hợp lệ từ server.", nil, nil, nil, nil, nil, false)
                            }
                        }
                    } catch {
                        completion(false, "Lỗi phân tích phản hồi: \(error.localizedDescription)", nil, nil, nil, nil, nil, false)
                    }
                }
            }.resume()
        }
    
    
    
    static func updateUserProfile(firstName: String?, lastName: String?, username: String?, completion: @escaping (Bool, String?) -> Void) {
        
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            completion(false, "Không tìm thấy token.")
            return
        }
        
        guard let url = URL(string: "https://travel-api-79ct.onrender.com/api/v1/users/me") else {
            completion(false, "URL không hợp lệ.")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [:]
        if let firstName = firstName { body["first_name"] = firstName }
        if let lastName = lastName { body["last_name"] = lastName }
        if let username = username { body["username"] = username }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(false, "Lỗi mã hóa dữ liệu: \(error.localizedDescription)")
            return
        }
        
        // ✅ Sử dụng session tùy chỉnh
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
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "Không có phản hồi từ server.")
                    return
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    completion(true, nil)
                } else {
                    completion(false, "Cập nhật thất bại. Mã lỗi: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
}
