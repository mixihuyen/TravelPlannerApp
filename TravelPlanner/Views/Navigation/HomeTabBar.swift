import SwiftUI

struct HomeTabBar: View {
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    @StateObject private var participantViewModel = ParticipantViewModel() // Để gọi API join
    @StateObject private var imageViewModel = ImageViewModel()
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.background2
        
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.pink
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.pink]
        
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Bảng tin", systemImage: "house")
                    }
                    .environmentObject(imageViewModel)
                TripView()
                    .tabItem {
                        Label("Kế hoạch", systemImage: "calendar")
                    }
                    .environmentObject(navigationCoordinator) // Truyền để TripView biết khi nào refresh
                ProfileView()
                    .tabItem {
                        Label("Hồ sơ", systemImage: "face.smiling")
                    }
                    .environmentObject(imageViewModel)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
        .alert(isPresented: $navigationCoordinator.showJoinAlert) {
            Alert(
                title: Text("Tham gia chuyến đi"),
                message: Text("Bạn có muốn tham gia chuyến đi này không?"),
                primaryButton: .default(Text("Chấp nhận")) {
                    if let tripId = navigationCoordinator.pendingTripId {
                        participantViewModel.joinTrip(tripId: tripId) {
                            navigationCoordinator.shouldRefreshTrips = true // Báo hiệu fetch lại trips
                            navigationCoordinator.pendingTripId = nil
                            navigationCoordinator.showJoinAlert = false
                            // Hiển thị toast nếu cần
                            participantViewModel.showToast(message: "Tham gia chuyến đi thành công!", type: .success)
                        }
                    }
                },
                secondaryButton: .cancel(Text("Từ chối")) {
                    navigationCoordinator.pendingTripId = nil
                    navigationCoordinator.showJoinAlert = false
                }
            )
        }
    }
    
    private func handleDeepLink(url: URL) {
        guard url.scheme == "myapp",
              url.host == "trip",
              url.path == "/join" else {
            print("❌ Unsupported URL scheme or path: \(url)")
            return
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let tripIdString = queryItems.first(where: { $0.name == "tripId" })?.value,
              let tripId = Int(tripIdString) else {
            print("❌ Invalid deep link format: \(url)")
            return
        }
        
        print("🚪 Received deep link with tripId: \(tripId)")
        navigationCoordinator.pendingTripId = tripId
        navigationCoordinator.showJoinAlert = true
    }
}
