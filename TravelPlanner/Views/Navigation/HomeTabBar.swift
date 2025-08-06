import SwiftUI

struct HomeTabBar: View {
    
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
        ZStack(alignment: .topTrailing)  {
            
            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                TripView()
                    .tabItem {
                        Label("Plan", systemImage: "calendar")
                    }
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "face.smiling")
                    }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

