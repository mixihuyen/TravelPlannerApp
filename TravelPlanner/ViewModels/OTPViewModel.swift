import Foundation
import Combine

class OTPViewModel: ObservableObject {
    @Published var otp: [String] = Array(repeating: "", count: 4)
    @Published var timeRemaining: Int = 30
    @Published var isResendEnabled: Bool = false
    @Published var isLoading: Bool = false
    @Published var alertMessage: String? = nil
    
    var navManager: NavigationManager?
    var authManager: AuthManager?
    var email: String = ""
    
    private var timer: Timer?
    private let authService = AuthService()
    private var cancellables = Set<AnyCancellable>()
    
    func startTimer() {
        timer?.invalidate()
        timeRemaining = 30
        isResendEnabled = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.timer?.invalidate()
                self.isResendEnabled = true
            }
        }
    }
    
    func invalidateTimer() {
        timer?.invalidate()
    }
    
    // Gửi lại mã OTP
    func resendCode() {
        print("🔁 Gửi lại mã OTP cho: \(email)")
        alertMessage = nil
        isLoading = true
        startTimer()
        
        AuthService.sendOTPRequest(to: email) { [weak self] success, message in
            guard let self = self else { return }
            self.isLoading = false
            
            if success {
                print("✅ Gửi lại OTP thành công")
                self.alertMessage = "Mã OTP đã được gửi lại."
            } else {
                self.alertMessage = message
            }
        }
    }
    
    // Gửi mã OTP để xác thực
    func submitOTP() {
        let enteredCode = otp.joined()
        alertMessage = nil
        
        guard enteredCode.count == 4, enteredCode.allSatisfy({ $0.isNumber }) else {
            alertMessage = "Vui lòng nhập đúng 4 chữ số OTP."
            return
        }
        
        print("📩 Gửi OTP: \(enteredCode)")
        verifyOTP(code: enteredCode)
        
        
    }
    
    
    func verifyOTP(code: String) {
            isLoading = true
            
            let requestBody: [String: String] = [
                "email": email,
                "otp": code
            ]
            
            authService.verifyOTP(request: requestBody)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    switch completion {
                    case .failure(let error):
                        print("❌ OTP verification failed: \(error)")
                        if error._code == NSURLErrorNotConnectedToInternet {
                            self.alertMessage = "Không có kết nối mạng. Vui lòng kiểm tra và thử lại."
                        } else {
                            self.alertMessage = error.localizedDescription
                        }
                    case .finished:
                        break
                    }
                } receiveValue: { [weak self] response in
                    guard let self = self else { return }
                    
                    if response.success {
                        guard let data = response.data else {
                            print("❌ No data in response")
                            self.alertMessage = "Không nhận được dữ liệu từ server."
                            return
                        }
                        
                        print("✅ OTP verified successfully")
                        print("🔍 AccessToken: \(data.token.accessToken)")
                        print("🔍 RefreshToken: \(data.token.refreshToken)")
                        
                        // Gọi hàm signIn từ AuthManager
                        self.authManager?.signIn(
                            token: data.token.accessToken,
                            refreshToken: data.token.refreshToken,
                            firstName: data.user.firstName,
                            lastName: data.user.lastName,
                            username: data.user.username,
                            email: self.email,
                            userId: Int(data.user.id)
                        )
                        
                        // Thông báo thành công
                        self.alertMessage = response.message
                    } else {
                        print("❌ OTP verification failed: \(response.message)")
                        self.alertMessage = response.message // Hiển thị message từ response
                    }
                }
                .store(in: &cancellables)
        }
    
}
