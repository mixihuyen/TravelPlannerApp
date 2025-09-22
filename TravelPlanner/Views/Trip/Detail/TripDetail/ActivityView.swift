import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var navManager: NavigationManager
    @EnvironmentObject var activityViewModel: ActivityViewModel
    @EnvironmentObject var viewModel: TripViewModel
    @Environment(\.horizontalSizeClass) var size
    let tripId: Int
    let tripDayId: Int
    
    private var trip: TripModel? {
        viewModel.trips.first { $0.id == tripId }
    }
    
    var columns: [GridItem] {
        if size == .compact {
            return [GridItem(.flexible())]
        } else {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
    }
    
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            
            // ScrollView cho header và danh sách hoạt động
            ScrollView {
                VStack {
                    HStack {
                        Button(action: {
                            navManager.goBack()
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20))
                                Spacer()
                                Text("Hoạt động")
                                    .font(.system(size: 18, weight: .bold))
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(.top, 15)
                    HStack {
                        Spacer()
                        let currentUserId = UserDefaults.standard.integer(forKey: "userId")
                        let userRole = trip?.tripParticipants?.first(where: { $0.userId == currentUserId })?.role ?? "Unknown"
                        
                        if userRole != "member" {
                            Button(action: {
                                navManager.go(to: .addActivity(tripId: tripId, tripDayId: tripDayId))
                            }) {
                                Image(systemName: "text.badge.plus")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.bottom, 15)
                    
                    GeometryReader { geometry in
                        let size = geometry.size.width
                        let costs = activityViewModel.calculateTotalCosts(for: tripDayId)
                        HStack {
                            WeatherCardView(
                                tripId: tripId,
                                tripDayId: tripDayId,
                                location: trip?.address ?? "Unknown"
                            )
                            .frame(width: size * 0.35)
                            
                            TotalCostCardView(
                                totalActualCost: costs.totalActualCost,
                                totalEstimatedCost: costs.totalEstimatedCost
                            )
                        }
                    }
                    .frame(height: 140)
                    if activityViewModel.isLoading {
                        LottieView(animationName: "loading2")
                            .frame(width: 100, height: 100)
                            .padding(.top, 150)
                    } else if activityViewModel.activities.isEmpty {
                        VStack {
                            Image("empty")
                                .resizable()
                                .frame(width: size == .compact ? 100 : 120, height: size == .compact ? 100 : 120)
                                .foregroundColor(.gray)
                            
                            Text("Chưa có hoạt động nào")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 150)
                    } else {
                        LazyVGrid(columns: columns, spacing: size == .compact ? 16 : 20) {
                            ForEach(activityViewModel.activities, id: \.id) { activity in
                                ActivityCardView(
                                    activity: activity,
                                    tripId: tripId,
                                    tripDayId: tripDayId
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarBackButtonHidden(true)
        .overlay(
            Group {
                if activityViewModel.showToast, let message = activityViewModel.toastMessage, let type = activityViewModel.toastType {
                    ToastView(message: message, type: type)
                }
            },
            alignment: .bottom
        )
        .onAppear {
            print("📋 Kiểm tra ActivityViewModel trong ActivityView: \(String(describing: activityViewModel))")
            print("📅 TripDayId: \(tripDayId)")
            // Chỉ fetch nếu không có dữ liệu cache cho tripDayId
            if activityViewModel.activities.filter({ $0.tripDayId == tripDayId }).isEmpty {
                activityViewModel.fetchActivities(tripDayId: tripDayId) {
                    print("📋 Hoạt động cho tripDayId \(tripDayId): \(activityViewModel.activities.map { "\($0.activity) (ID: \($0.id))" })")
                }
            } else {
                print("📂 Cache đã có \(activityViewModel.activities.count) activities cho tripDayId \(tripDayId), bỏ qua fetch")
                // Kích hoạt refreshTrigger để đảm bảo UI cập nhật
                activityViewModel.refreshTrigger = UUID()
            }
        }
        .onChange(of: activityViewModel.refreshTrigger) { _ in
            print("🔄 RefreshTrigger activated, updating UI with \(activityViewModel.activities.count) activities")
        }
        
        
    }
}
