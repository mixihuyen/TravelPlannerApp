import SwiftUI

struct RootView: View {
    @StateObject private var navManager = NavigationManager()
    @StateObject private var authManager: AuthManager
    
    init() {
        let navManager = NavigationManager()
        self._navManager = StateObject(wrappedValue: navManager)
        self._authManager = StateObject(wrappedValue: AuthManager(navigationManager: navManager))
    }
    
    var body: some View {
        NavigationStack(path: $navManager.path) {
            ZStack {
                // Nội dung chính dựa trên trạng thái đăng nhập
                if authManager.isAuthenticated {
                    HomeTabBar()
                } else {
                    FirstView()
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .register:
                    RegisterView()
                case .signin:
                    SignInView()
                case .verifyEmail:
                    VerifyView()
                case .otpview(let email):
                    OTPView(email: email)
                case .nameView:
                    NameView()
                case .usernameView:
                    UserNameView()
                case .homeTabBar:
                    HomeTabBar()
                case .tripView:
                    TripView()
                case .createTrip:
                    CreateTripPopup()
                }
            }
        }
        .environmentObject(navManager)
        .environmentObject(authManager)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
