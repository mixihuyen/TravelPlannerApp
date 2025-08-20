import Foundation
import Combine

class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUserName: String?
    @Published var currentUserEmail: String?
    @Published var username: String?
    private var navManager: NavigationManager?
    
    init(navigationManager: NavigationManager? = nil) {
        self.navManager = navigationManager
        checkIfLoggedIn()
    }
    
    func checkIfLoggedIn() {
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            isAuthenticated = true
            let firstName = UserDefaults.standard.string(forKey: "firstName")
            let lastName = UserDefaults.standard.string(forKey: "lastName")
            self.currentUserName = [firstName, lastName].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            self.currentUserEmail = UserDefaults.standard.string(forKey: "userEmail")
            self.username = UserDefaults.standard.string(forKey: "username")
        } else {
            isAuthenticated = false
            self.currentUserName = nil
            self.currentUserEmail = nil
            self.username = nil
        }
    }
    
    func avatarInitials() -> String {
        let firstInitial = UserDefaults.standard.string(forKey: "firstName")?.prefix(1) ?? ""
        let lastInitial = UserDefaults.standard.string(forKey: "lastName")?.prefix(1) ?? ""
        return "\(firstInitial)\(lastInitial)".uppercased()
    }

    
    func signIn(token: String, firstName: String?, lastName: String?, username: String?, email: String?, userId: Int?) {
        UserDefaults.standard.set(token, forKey: "authToken")
        UserDefaults.standard.set(firstName, forKey: "firstName")
        UserDefaults.standard.set(lastName, forKey: "lastName")
        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(email, forKey: "userEmail")
        UserDefaults.standard.set(userId, forKey: "userId")
        self.currentUserName = [firstName, lastName].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        self.currentUserEmail = email
        self.username = username
        isAuthenticated = true
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "firstName")
        UserDefaults.standard.removeObject(forKey: "lastName")
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "userId")
        self.currentUserName = nil
        self.currentUserEmail = nil
        self.username = nil
        isAuthenticated = false
        navManager?.goToRoot()
    }
    
    func setNavigationManager(_ navManager: NavigationManager) {
        self.navManager = navManager
    }
}
