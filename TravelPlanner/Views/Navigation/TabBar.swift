import SwiftUI

struct TabBar: View {
    let tripId: Int
    @Environment(\.dismiss) var dismiss
    @State private var showBottomSheet = false
    @EnvironmentObject var viewModel: TripViewModel
    @EnvironmentObject var navManager: NavigationManager
    @StateObject private var tripDetailViewModel: TripDetailViewModel
    private let networkManager = NetworkManager.shared
    @State private var localTrip: TripModel?

    
    private var trip: TripModel? {
        viewModel.trips.first { $0.id == tripId }
    }
    
    init(tripId: Int) {
        self.tripId = tripId
        self._tripDetailViewModel = StateObject(wrappedValue: TripDetailViewModel(tripId: tripId))
        
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.background2
        
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.pink
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.pink]
        
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        print("📋 Khởi tạo TabBar với tripId: \(tripId)")
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let trip = localTrip{
                TabView {
                    TripDetailView(tripId: tripId)
                        .tabItem {
                            Label("Lịch trình", systemImage: "calendar")
                        }
                        .environmentObject(tripDetailViewModel)
                    
                    MembersView(tripId: tripId)
                        .tabItem {
                            Label("Thành viên", systemImage: "person.2.fill")
                        }
                    
                    PackingListView(viewModel: PackingListViewModel(tripId: tripId))
                        .tabItem {
                            Label("Mang theo", systemImage: "duffle.bag.fill")
                        }
                    
                    StatisticalView(tripId: tripId)
                        .tabItem {
                            Label("Chi tiêu", systemImage: "dollarsign.circle.fill")
                        }
                }
                .onAppear {
                    print("📋 TabBar xuất hiện với tripId: \(tripId)")
                }
                
                HStack(spacing: 5) {
                    Button(action: {
                        let currentUserId = UserDefaults.standard.integer(forKey: "userId")
                        let userRole = trip.tripParticipants?.first(where: { $0.userId == currentUserId })?.role ?? "Unknown"
                        
                        if userRole.lowercased() == "owner" {
                            showBottomSheet = true
                        } else {
                            tripDetailViewModel.showToast(message: "Chỉ có owner mới có thể chỉnh sửa chuyến đi", type: .error)
                        }
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                            .padding(.leading, 5)
                    }
                    
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
            } else {
                ZStack {
                    Color.pink.opacity(0.4)                             .ignoresSafeArea()
                     LottieView(animationName: "loading2")
                         .frame(width: 50, height: 50)
                }
                    
            }
        }
        
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showBottomSheet) {
            DeleteTripBottomSheet(
                onDelete: {
                    viewModel.deleteTrip(id: tripId) { success in
                        if success {
                            withAnimation {
                                showBottomSheet = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                viewModel.toastMessage = "Xoá chuyến đi thành công!"
                                viewModel.showToast = true
                                    navManager.goBack()
                            }
                        } else {
                            withAnimation {
                                showBottomSheet = false
                            }
                            tripDetailViewModel.showToast(message: "Không thể xóa chuyến đi", type: .error)
                        }
                    }
                },
                onCancel: {
                    withAnimation {
                        showBottomSheet = false
                    }
                },
                isOffline: !NetworkManager.isConnected()
            )
            .presentationDetents([.height(300)])
            .presentationBackground(.clear)
            .background(Color.background)
            .ignoresSafeArea()
            .environmentObject(navManager)
        }
        .onAppear {
            if localTrip == nil { // chỉ gán lần đầu
                localTrip = viewModel.trips.first { $0.id == tripId }
            }
            print("📋 TabBar xuất hiện với tripId: \(tripId)")
        }

    }
}
