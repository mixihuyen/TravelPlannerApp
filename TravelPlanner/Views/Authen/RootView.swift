import SwiftUI

struct RootView: View {
    @StateObject private var navManager = NavigationManager()
    @StateObject private var authManager: AuthManager
    @StateObject private var viewModel = TripViewModel()
    
    init() {
        let navManager = NavigationManager()
        self._navManager = StateObject(wrappedValue: navManager)
        self._authManager = StateObject(wrappedValue: AuthManager(navigationManager: navManager))
    }
    
    var body: some View {
        NavigationStack(path: $navManager.path) {
            ZStack {
                if authManager.isAuthenticated {
                    HomeTabBar()
                } else {
                    FirstView()
                }
            }
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
                    case .tripDetailView(let trip):
                        TripDetailView(trip: trip)
                    case .createTrip:
                        CreateTripView()
                    case .tabBarView(let trip):
                        TabBar(trip: trip)
                    case .activity(let date, let activities, let trip):
                        ActivityView(date: date, trip: trip)
                            .environmentObject(TripDetailViewModel(trip: trip))
                    case .addActivity(let date, let trip, let tripDayId):
                        AddActivityView(selectedDate: date, trip: trip, tripDayId: tripDayId)
                            .environmentObject(TripDetailViewModel(trip: trip))
                    case .editActivity(let date, let activity, let trip, let tripDayId):
                        EditActivityView(selectedDate: date, trip: trip, activity: activity, tripDayId: tripDayId)
                            .environmentObject(TripDetailViewModel(trip: trip))
                    }
                }
            }
        }
        .environmentObject(viewModel)
        .environmentObject(navManager)
        .environmentObject(authManager)
    }
}
