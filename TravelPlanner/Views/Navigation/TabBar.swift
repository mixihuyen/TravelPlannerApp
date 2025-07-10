import SwiftUI

struct TabBar: View {
    var trip: TripModel
    @Environment(\.dismiss) var dismiss
    @State var packingList: PackingList
    
    init(trip: TripModel) {
        self.trip = trip
        self._packingList = State(initialValue: trip.packingList)
        
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
                TripDetailView(trip: trip)
                    .tabItem {
                        Label("Lịch trình", systemImage: "calendar")
                    }
                
                MembersView(trip: trip, members: trip.members)
                    .tabItem {
                        Label("Thành viên", systemImage: "person.2.fill")
                    }
                
                PackingListView(
                    viewModel: PackingListViewModel(
                        packingList: trip.packingList,
                        members: trip.members
                    )
                )
                .tabItem {
                    Label("Mang theo", systemImage: "duffle.bag.fill")
                }
                
                StatisticalView(trip: trip)
                    .tabItem {
                        Label("Chi tiêu", systemImage: "dollarsign.circle.fill")
                    }
            }
            
            HStack(spacing: 5) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 40, height: 40)
                    .foregroundColor(.white)
                    .padding(.leading, 5)
                
                Rectangle()
                    .frame(width: 1, height: 24)
                    .foregroundColor(.gray.opacity(0.3))
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 40, height: 40)
                        .foregroundColor(.white)
                        .padding(.trailing, 5)
                }
            }
            .background(Color.gray.opacity(0.2))
            .clipShape(Capsule())
            .padding(.horizontal)
        }
        .navigationBarBackButtonHidden(true)
    }
}

