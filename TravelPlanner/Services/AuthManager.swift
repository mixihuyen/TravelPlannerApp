import Foundation
import Combine

class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUserName: String?
    @Published var username: String?
    @Published var avatarUrl: String? // Add avatarUrl property
    private var navManager: NavigationManager?
    private let cacheManager = CacheManager.shared
    
    init(navigationManager: NavigationManager? = nil) {
        self.navManager = navigationManager
        checkIfLoggedIn()
    }
    
    private func navigateBasedOnState(firstName: String?, lastName: String?, username: String?) {
        if (firstName?.isEmpty ?? true) && (lastName?.isEmpty ?? true) && (username?.isEmpty ?? true) {
            // TH1: Cả firstName, lastName và username đều rỗng
            isAuthenticated = false
            self.currentUserName = nil
            self.username = nil
            self.avatarUrl = nil // Reset avatarUrl
            navManager?.go(to: .nameView)
        } else if !(firstName?.isEmpty ?? true) && !(lastName?.isEmpty ?? true) && (username?.isEmpty ?? true) {
            // TH2: Cả firstName và lastName không rỗng, nhưng username rỗng
            isAuthenticated = false
            self.currentUserName = [firstName, lastName].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            self.username = nil
            self.avatarUrl = nil // Reset avatarUrl
            navManager?.go(to: .usernameView)
        } else if !(firstName?.isEmpty ?? true) && !(lastName?.isEmpty ?? true) && !(username?.isEmpty ?? true) {
            // TH3: Cả firstName, lastName và username không rỗng
            isAuthenticated = true
            self.currentUserName = [firstName, lastName].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            self.username = username
            self.avatarUrl = UserDefaults.standard.string(forKey: "avatarUrl") // Load avatarUrl
            navManager?.go(to: .homeTabBar)
        } else {
            // Trường hợp bất thường: chỉ một trong firstName hoặc lastName không rỗng
            isAuthenticated = false
            self.currentUserName = nil
            self.username = nil
            self.avatarUrl = nil // Reset avatarUrl
            navManager?.go(to: .nameView)
        }
    }
    
    func checkIfLoggedIn() {
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            let firstName = UserDefaults.standard.string(forKey: "firstName")
            let lastName = UserDefaults.standard.string(forKey: "lastName")
            let username = UserDefaults.standard.string(forKey: "username")
            self.avatarUrl = UserDefaults.standard.string(forKey: "avatarUrl") // Load avatarUrl
            navigateBasedOnState(firstName: firstName, lastName: lastName, username: username)
        } else {
            isAuthenticated = false
            self.currentUserName = nil
            self.username = nil
            self.avatarUrl = nil // Reset avatarUrl
            navManager?.goToRoot()
        }
    }
    
    func avatarInitials() -> String {
        let firstInitial = UserDefaults.standard.string(forKey: "firstName")?.prefix(1) ?? ""
        let lastInitial = UserDefaults.standard.string(forKey: "lastName")?.prefix(1) ?? ""
        return "\(firstInitial)\(lastInitial)".uppercased()
    }
    
    func signIn(token: String, refreshToken: String, firstName: String?, lastName: String?, username: String?, email: String?, userId: Int?, avatarUrl: String? = nil) {
        UserDefaults.standard.set(token, forKey: "authToken")
        UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
        UserDefaults.standard.set(firstName, forKey: "firstName")
        UserDefaults.standard.set(lastName, forKey: "lastName")
        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(email, forKey: "userEmail")
        UserDefaults.standard.set(userId, forKey: "userId")
        UserDefaults.standard.set(avatarUrl, forKey: "avatarUrl") // Save avatarUrl
        self.currentUserName = [firstName, lastName].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        self.username = username
        self.avatarUrl = avatarUrl // Set avatarUrl
        navigateBasedOnState(firstName: firstName, lastName: lastName, username: username)
    }
    
    func logout() {
        // Xóa toàn bộ cache qua CacheManager
        cacheManager.clearAllCache()
        
        // Gửi thông báo đăng xuất
        NotificationCenter.default.post(name: .didLogout, object: nil)
        
        // Cập nhật trạng thái
        self.currentUserName = nil
        self.username = nil
        self.avatarUrl = nil // Reset avatarUrl
        isAuthenticated = false
    }
    
    func setNavigationManager(_ navManager: NavigationManager) {
        self.navManager = navManager
    }
}

extension NSNotification.Name {
    static let didLogout = Notification.Name("didLogout")
}
