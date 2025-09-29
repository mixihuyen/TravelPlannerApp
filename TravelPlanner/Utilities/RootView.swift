import SwiftUI

struct RootView: View {
    @State private var showAlert: Bool = false
        @State private var alertTitle: String = ""
        @State private var alertMessage: String = ""
    @StateObject private var navManager = NavigationManager()
    @StateObject private var authManager: AuthManager
    @StateObject private var viewModel = TripViewModel()
    @State private var activityViewModels: [Int: ActivityViewModel] = [:]
    
    init() {
        let navManager = NavigationManager()
        self._navManager = StateObject(wrappedValue: navManager)
        self._authManager = StateObject(wrappedValue: AuthManager(navigationManager: navManager))
    }
    private func getOrCreateActivityViewModel(for tripId: Int) -> ActivityViewModel {
        if let existingViewModel = activityViewModels[tripId] {
            print("📋 Reusing ActivityViewModel for tripId=\(tripId), instance: \(Unmanaged.passUnretained(existingViewModel).toOpaque())")
            return existingViewModel
        } else {
            let newViewModel = ActivityViewModel(tripId: tripId)
            activityViewModels[tripId] = newViewModel
            print("📋 Created new ActivityViewModel for tripId=\(tripId), instance: \(Unmanaged.passUnretained(newViewModel).toOpaque())")
            return newViewModel
        }
    }
    
    var body: some View {
        NavigationStack(path: $navManager.path) {
            FirstView()
                .navigationDestination(for: Route.self) { route in
                    Group {
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
                            CreateTripView()
                        case .editTrip(let trip):
                            EditTripView(trip: trip)
                                .environmentObject(navManager)
                                .environmentObject(viewModel)
                        case .tabBarView(let tripId):
                            TabBar(tripId: tripId)
                                .environmentObject(viewModel)
                                .environmentObject(navManager)
                        case .tripDetailView(let tripId):
                            TripDetailView(tripId: tripId)
                                .environmentObject(viewModel)
                                .environmentObject(navManager)
                                .environmentObject(getOrCreateActivityViewModel(for: tripId))
                        case .activity(let tripId, let tripDayId):
                            ActivityView(tripId: tripId, tripDayId: tripDayId)
                                .environmentObject(viewModel)
                                .environmentObject(navManager)
                                .environmentObject(getOrCreateActivityViewModel(for: tripId))
                            
                        case .addActivity(let tripId, let tripDayId):
                            AddActivityView(tripId: tripId, tripDayId: tripDayId)
                                .environmentObject(navManager)
                                .environmentObject(getOrCreateActivityViewModel(for: tripId))
                            
                        case .editActivity(let tripId, let tripDayId, let activity):
                            EditActivityView(tripId: tripId, activity: activity, tripDayId: tripDayId)
                                .environmentObject(navManager)
                                .environmentObject(getOrCreateActivityViewModel(for: tripId))
                        case .activityImages(let tripId, let tripDayId, let activityId):
                            ActivityImagesView(tripId: tripId, tripDayId: tripDayId, activityId: activityId)
                                .environmentObject(navManager)
                                .environmentObject(getOrCreateActivityViewModel(for: tripId))
                            
                            
                            
                            
                            
                        }
                        
                    }
                }
        }
        .environmentObject(viewModel)
        .environmentObject(navManager)
        .environmentObject(authManager)
        .environment(\.managedObjectContext, CoreDataStack.shared.context)
        .onAppear {
            print("📋 RootView xuất hiện")
        }
        .onDisappear {
            print("🗑️ RootView biến mất")
        }
        .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text(alertTitle),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK")) {
                            if alertTitle == "Phiên Đăng Nhập Hết Hạn" {
                                authManager.logout()
                            }
                        }
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: .showAuthErrorAlert)) { notification in
                    // Chỉ hiển thị alert nếu chưa có alert nào đang hiển thị
                    guard !showAlert else {
                        print("⚠️ Alert already being shown, skipping new alert")
                        return
                    }
                    
                    if let userInfo = notification.userInfo,
                       let title = userInfo["title"] as? String,
                       let message = userInfo["message"] as? String {
                        alertTitle = title
                        alertMessage = message
                        showAlert = true
                        print("🔔 Displaying alert: \(title) - \(message)")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .didLogout)) { _ in
                    print("🚪 Received didLogout notification, navigating to signin")
                    navManager.goToRoot()
                }
            
    }
}
