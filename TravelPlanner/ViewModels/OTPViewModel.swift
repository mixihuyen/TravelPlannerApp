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
        AuthService.verifyOTP(email: email, code: code) { [weak self] success, message, token, firstName, lastName, username,userId, shouldGoToHome in guard let self = self else { return }
            self.isLoading = false
            
            if success {
                print("✅ OTP hợp lệ")
                if let token = token {
                    self.authManager?.signIn(token: token, firstName: firstName, lastName: lastName, username: username, email: self.email, userId: userId)
                }
                
                if shouldGoToHome {
                    self.navManager?.go(to: .homeTabBar)
                } else {
                    self.navManager?.go(to: .nameView)
                }
            } else {
                self.alertMessage = message
            }
        }
        
        
    }
    
}
