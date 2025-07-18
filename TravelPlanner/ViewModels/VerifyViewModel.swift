import Foundation
import Combine

class VerifyViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var isLoading: Bool = false
    @Published var alertMessage: String? = nil
    @Published var shouldNavigateToOTP: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let maxRetries = 3
    private var retryCount = 0


    func verifyEmail() {
        
        guard isValidEmail() else {
            alertMessage = "Email không hợp lệ. Vui lòng kiểm tra lại."
            return
        }

        isLoading = true
        alertMessage = nil
        email = email.lowercased()

        AuthService.sendOTPRequest(to: email) { [weak self] success, message in
            guard let self = self else { return }
            self.isLoading = false

            if success {
                self.retryCount = 0
                self.shouldNavigateToOTP = true
            } else {
                self.retryCount += 1
                if self.retryCount < self.maxRetries {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.verifyEmail()
                    }
                } else {
                    self.alertMessage = message ?? "Đã xảy ra lỗi khi gửi mã OTP."
                }
            }
        }
    }


    private func isValidEmail() -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email) && !email.isEmpty
    }
}
