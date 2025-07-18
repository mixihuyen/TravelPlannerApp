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
    
    func signIn(token: String, firstName: String?, lastName: String?, username: String?, email: String?) {
        UserDefaults.standard.set(token, forKey: "authToken")
        UserDefaults.standard.set(firstName, forKey: "firstName")
        UserDefaults.standard.set(lastName, forKey: "lastName")
        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(email, forKey: "userEmail")
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
