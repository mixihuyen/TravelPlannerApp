import SwiftUI

struct TabBar: View {
    var trip: TripModel
    @Environment(\.dismiss) var dismiss
    @State private var showBottomSheet = false
    @EnvironmentObject var viewModel: TripViewModel
    @EnvironmentObject var navManager: NavigationManager
    @StateObject private var tripDetailViewModel: TripDetailViewModel
    
    
    init(trip: TripModel) {
        self.trip = trip
        self._tripDetailViewModel = StateObject(wrappedValue: TripDetailViewModel(trip: trip))
        
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.background2
        
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.pink
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.pink]
        
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        print("📋 Trip ID trong TabBar: \(trip.id)")
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing)  {
            
            TabView {
                TripDetailView(trip: trip)
                    .tabItem {
                        Label("Lịch trình", systemImage: "calendar")
                    }
                
                MembersView(trip: trip)
                    .tabItem {
                        Label("Thành viên", systemImage: "person.2.fill")
                    }
                
                PackingListView(
                    viewModel: PackingListViewModel(tripId: trip.id)
                )
                .tabItem {
                    Label("Mang theo", systemImage: "duffle.bag.fill")
                }
                
                StatisticalView(tripId: trip.id)
                    .tabItem {
                        Label("Chi tiêu", systemImage: "dollarsign.circle.fill")
                    }
            }
            .environmentObject(tripDetailViewModel)
            .onAppear {
                            print("📋 TripDetailViewModel được inject trong TabBar: \(tripDetailViewModel)")
                        }
            
            HStack(spacing: 5) {
                Button(action: {
                    let currentUserId = UserDefaults.standard.integer(forKey: "userId")
                    let userRole = trip.tripParticipants?.first(where: { $0.userId == currentUserId })?.role ?? "Unknown"
                    
                    if userRole == "owner" {
                        showBottomSheet = true
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
            
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showBottomSheet) {
            DeleteTripBottomSheet(
                onDelete: {
                    viewModel.deleteTrip(id: trip.id) { success in
                        if success {
                            withAnimation {
                                showBottomSheet = false
                                
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()) {
                                viewModel.toastMessage = "Xoá chuyến đi thành công!"
                                viewModel.showToast = true
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now()) {
                                    navManager.goToRoot()
                                }
                            }
                        } else {
                            withAnimation {
                                showBottomSheet = false
                            }
                            print("❌ Không xoá được")
                        }
                    }
                },
                onCancel: {
                    withAnimation {
                        showBottomSheet = false
                    }
                },
                isOffline: viewModel.isOffline
            )
            .presentationDetents([.height(300)])
            .presentationBackground(.clear)
            .background(Color.background)
            .ignoresSafeArea()
            .environmentObject(navManager)
        }
        .onAppear {
                    // Kiểm tra thêm khi view xuất hiện
                    print("📋 Trip ID khi TabBar xuất hiện: \(trip.id)")
                    if trip.id <= 0 {
                        print("⚠️ Cảnh báo: trip.id không hợp lệ (\(trip.id))")
                    }
                }
        
        
        
        
    }
}

