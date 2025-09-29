import Foundation
import Combine

class ProfileViewModel: ObservableObject {
    @Published var userInfo: UserInformation? 
    @Published var isLoading: Bool = false
    @Published var toastMessage: String?
    @Published var showToast: Bool = false
    @Published var toastType: ToastType?
    
    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager.shared
    
    init() {
        if NetworkManager.isConnected() {
            fetchUserProfile()
        } else {
            showToast(message: "Không có kết nối mạng, vui lòng kiểm tra lại!", type: .error)
        }
    }
    
    deinit {
        print("🗑️ ProfileViewModel deallocated")
    }
    
    // MARK: - Public Methods
    func fetchUserProfile(completion: (() -> Void)? = nil) {
            guard NetworkManager.isConnected() else {
                showToast(message: "Không có kết nối mạng, vui lòng thử lại!", type: .error)
                completion?()
                return
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)/users/me"),
                  let token = UserDefaults.standard.string(forKey: "authToken") else {
                showToast(message: "Không tìm thấy token xác thực", type: .error)
                completion?()
                return
            }
            
            let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
            isLoading = true
            
            networkManager.performRequest(request, decodeTo: UpdateProfileResponse.self)
                .sink { [weak self] completionResult in
                    guard let self else { return }
                    self.isLoading = false
                    switch completionResult {
                    case .failure(let error):
                        print("❌ Lỗi khi lấy thông tin cá nhân: \(error.localizedDescription)")
                        if let decodingError = error as? DecodingError {
                            switch decodingError {
                            case .dataCorrupted(let context):
                                print("🔍 Data corrupted: \(context.debugDescription)")
                            case .keyNotFound(let key, let context):
                                print("🔍 Key '\(key)' not found: \(context.debugDescription)")
                                self.showToast(message: "Dữ liệu từ server không đầy đủ!", type: .error)
                            case .typeMismatch(let type, let context):
                                print("🔍 Type '\(type)' mismatch: \(context.debugDescription)")
                            case .valueNotFound(let type, let context):
                                print("🔍 Value '\(type)' not found: \(context.debugDescription)")
                            @unknown default:
                                print("🔍 Lỗi decode không xác định")
                            }
                        } else {
                            self.showToast(message: "Lỗi khi tải thông tin cá nhân: \(error.localizedDescription)", type: .error)
                        }
                    case .finished:
                        print("✅ Lấy thông tin cá nhân thành công")
                    }
                    completion?()
                } receiveValue: { [weak self] response in
                    guard let self else { return }
                    if response.success, let userData = response.data {
                        self.userInfo = userData
                        // Save to UserDefaults for offline fallback
                        UserDefaults.standard.set(userData.firstName, forKey: "firstName")
                        UserDefaults.standard.set(userData.lastName, forKey: "lastName")
                        UserDefaults.standard.set(userData.username, forKey: "username")
                        print("📥 Thông tin người dùng: ID: \(userData.id), username: \(userData.username ?? "N/A")")
                    } else {
                        self.showToast(message: response.message, type: .error)
                    }
                }
                .store(in: &cancellables)
        }
    
    func refreshUserProfile() {
        isLoading = true
        fetchUserProfile { [weak self] in
            guard let self else { return }
            self.isLoading = false
            self.showToast(message: "Làm mới thông tin cá nhân thành công!", type: .success)
        }
    }
    
    func updateUserProfile(firstName: String, lastName: String, username: String, completion: @escaping (Bool) -> Void) {
            guard NetworkManager.isConnected() else {
                showToast(message: "Không có kết nối mạng, vui lòng thử lại!", type: .error)
                completion(false)
                return
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)/users/me"),
                  let token = UserDefaults.standard.string(forKey: "authToken") else {
                showToast(message: "Không tìm thấy token xác thực", type: .error)
                completion(false)
                return
            }
            
            let profileData = UpdateProfileRequest(firstName: firstName, lastName: lastName, username: username, avatarId: nil)
            
            guard let body = try? JSONEncoder().encode(profileData) else {
                print("❌ Lỗi mã hóa dữ liệu ProfileRequest")
                showToast(message: "Lỗi mã hóa dữ liệu", type: .error)
                completion(false)
                return
            }
            
            print("📤 Request body: \(String(data: body, encoding: .utf8) ?? "Không thể decode body")")
            let request = NetworkManager.createRequest(url: url, method: "PATCH", token: token, body: body)
            isLoading = true
            
            networkManager.performRequest(request, decodeTo: UpdateProfileResponse.self)
                .sink { [weak self] completionResult in
                    guard let self else {
                        completion(false)
                        return
                    }
                    self.isLoading = false
                    switch completionResult {
                    case .failure(let error):
                        print("❌ Lỗi khi cập nhật hồ sơ: \(error.localizedDescription)")
                        if (error as? URLError)?.code == .badServerResponse {
                            self.showToast(message: "Tên người dùng đã được sử dụng, vui lòng chọn tên khác!", type: .error)
                        } else if (error as? URLError)?.code == .userAuthenticationRequired {
                            self.showToast(message: "Phiên đăng nhập hết hạn, vui lòng đăng nhập lại!", type: .error)
                            NotificationCenter.default.post(name: NSNotification.Name("UserNeedsToLogin"), object: nil)
                        } else {
                            self.showToast(message: "Lỗi khi cập nhật hồ sơ: \(error.localizedDescription)", type: .error)
                        }
                        completion(false)
                    case .finished:
                        print("✅ Cập nhật hồ sơ thành công")
                        self.showToast(message: "Cập nhật thông tin thành công!", type: .success)
                        completion(true)
                    }
                } receiveValue: { [weak self] response in
                    guard let self else {
                        completion(false)
                        return
                    }
                    if response.success, let userData = response.data {
                        self.userInfo = userData
                        // Save updated profile data to UserDefaults
                        UserDefaults.standard.set(userData.firstName, forKey: "firstName")
                        UserDefaults.standard.set(userData.lastName, forKey: "lastName")
                        UserDefaults.standard.set(userData.username, forKey: "username")
                        print("📥 Cập nhật thông tin người dùng: ID: \(userData.id), username: \(userData.username ?? "N/A")")
                    } else {
                        self.showToast(message: response.message.isEmpty ? "Không thể cập nhật hồ sơ, vui lòng thử lại sau!" : response.message, type: .error)
                        completion(false)
                    }
                }
                .store(in: &cancellables)
        }
        
    
    // Helper function to generate avatar initials
    func avatarInitials() -> String {
        guard let userInfo = userInfo else { return "" }
        let firstInitial = userInfo.firstName?.first?.uppercased() ?? ""
        let lastInitial = userInfo.lastName?.first?.uppercased() ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
    
    // Helper function to generate full name
    func userFullName() -> String {
        guard let userInfo = userInfo else { return "Khách" }
        let firstName = userInfo.firstName ?? ""
        let lastName = userInfo.lastName ?? ""
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Helper Methods
    func showToast(message: String, type: ToastType) {
        print("📢 Đặt toast: \(message) với type: \(type)")
        DispatchQueue.main.async {
            self.toastMessage = message
            self.toastType = type
            self.showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                print("📢 Ẩn toast")
                self.showToast = false
                self.toastMessage = nil
                self.toastType = nil
            }
        }
    }
}
