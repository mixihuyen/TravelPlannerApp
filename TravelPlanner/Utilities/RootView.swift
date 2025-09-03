import SwiftUI

struct RootView: View {
    @StateObject private var navManager = NavigationManager()
    @StateObject private var authManager: AuthManager
    @StateObject private var viewModel = TripViewModel()
    @State private var tripDetailViewModels: [Int: TripDetailViewModel] = [:] // Lưu trữ TripDetailViewModel theo trip.id
    
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
                    case .createTrip:
                        CreateTripView()
                    case .editTrip(let trip): // Thêm route cho EditTripView
                                            EditTripView(trip: trip)
                                                .environmentObject(navManager)
                                                .environmentObject(viewModel)
                    case .tabBarView(let trip):
                        TabBar(trip: trip)
                    case .tripDetailView(let trip):
                        // Tạo hoặc lấy TripDetailViewModel cho trip.id
                        let tripDetailViewModel = getOrCreateTripDetailViewModel(for: trip)
                        TripDetailView(tripId: trip.id) 
                            .environmentObject(navManager)
                            .environmentObject(tripDetailViewModel)
                    case .activity(let date, _, let trip, let tripDayId):
                        let tripDetailViewModel = getOrCreateTripDetailViewModel(for: trip)
                        ActivityView(date: date, trip: trip, tripDayId: tripDayId)
                            .environmentObject(navManager)
                            .environmentObject(tripDetailViewModel)
                    case .addActivity(let date, let trip, let tripDayId):
                        let tripDetailViewModel = getOrCreateTripDetailViewModel(for: trip)
                        AddActivityView(selectedDate: date, trip: trip, tripDayId: tripDayId)
                            .environmentObject(navManager)
                            .environmentObject(tripDetailViewModel)
                    case .editActivity(let date, let activity, let trip, let tripDayId):
                        let tripDetailViewModel = getOrCreateTripDetailViewModel(for: trip)
                        EditActivityView(selectedDate: date, trip: trip, activity: activity, tripDayId: tripDayId)
                            .environmentObject(navManager)
                            .environmentObject(tripDetailViewModel)
                    case .activityImages(let tripId, let tripDayId, let activityId):
                                            ActivityImagesView(tripId: tripId, tripDayId: tripDayId, activityId: activityId)
                                                .environmentObject(navManager)
                                        
                    }
                    
                }
            }
        }
        .environmentObject(viewModel)
        .environmentObject(navManager)
        .environmentObject(authManager)
        .environment(\.managedObjectContext, CoreDataStack.shared.context)
    }
    
    private func getOrCreateTripDetailViewModel(for trip: TripModel) -> TripDetailViewModel {
        if let existingViewModel = tripDetailViewModels[trip.id] {
            print("🔄 Tái sử dụng TripDetailViewModel cho tripId=\(trip.id)")
            return existingViewModel
        } else {
            let newViewModel = TripDetailViewModel(trip: trip)
            tripDetailViewModels[trip.id] = newViewModel
            print("🆕 Tạo mới TripDetailViewModel cho tripId=\(trip.id)")
            return newViewModel
        }
    }
}
