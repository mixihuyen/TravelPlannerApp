import SwiftUI

struct ActivityView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var navManager: NavigationManager
    let date: Date
    let trip: TripModel
    @EnvironmentObject var viewModel: TripDetailViewModel
    @State private var tripDayId: Int?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.background.ignoresSafeArea()
            
            ScrollView {
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
                .padding(.horizontal)
                
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            if let tripDayId = tripDayId {
                                navManager.go(to: .addActivity(date: date, trip: trip, tripDayId: tripDayId))
                            } else {
                                viewModel.showToast(message: "Không thể thêm hoạt động: Không tìm thấy ngày chuyến đi")
                            }
                        }) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 15)
                    
                    GeometryReader { geometry in
                        let size = geometry.size.width
                        HStack {
                            WeatherCardView()
                                .frame(width: size * 0.35)
                            
                            TotalCostCardView(
                                totalActualCost: viewModel.calculateTotalCosts(for: date).actualCost,
                                totalEstimatedCost: viewModel.calculateTotalCosts(for: date).estimatedCost
                            )
                        }
                    }
                    .frame(height: 140)
                    
                    HStack {
                        let activities = viewModel.activities(for: date)
                        if activities.isEmpty {
                            VStack(spacing: 8) {
                                Image("empty")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.gray)
                                
                                Text("Chưa có hoạt động nào cho ngày \(dateFormatter.string(from: date))")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                        } else {
                            VStack(spacing: 16) {
                                ForEach(activities, id: \.id) { activity in
                                    Button(action: {
                                        if let tripDayId = tripDayId {
                                            navManager.go(to: .editActivity(date: date, activity: activity, trip: trip, tripDayId: tripDayId))
                                        } else {
                                            viewModel.showToast(message: "Không thể chỉnh sửa hoạt động: Không tìm thấy ngày chuyến đi")
                                        }
                                    }) {
                                        ActivityCardView(activity: activity)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .overlay(
                Group {
                    if viewModel.showToast, let message = viewModel.toastMessage {
                        SuccessToastView(message: message)
                    }
                },
                alignment: .bottom
            )
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            print("📋 Kiểm tra TripDetailViewModel trong ActivityView: \(String(describing: viewModel))")
            print("📅 Ngày được chọn: \(dateFormatter.string(from: date))")
            viewModel.clearCache()
            viewModel.fetchTripDays(forceRefresh: true)
            viewModel.getTripDayId(for: date) { tripDayId in
                self.tripDayId = tripDayId
                if tripDayId == nil {
                    print("❌ Không tìm thấy tripDayId cho ngày: \(dateFormatter.string(from: date))")
                    viewModel.showToast(message: "Không tìm thấy ngày chuyến đi")
                } else {
                    print("✅ Đã lấy tripDayId: \(tripDayId!) cho ngày: \(dateFormatter.string(from: date))")
                    let activities = viewModel.activities(for: date)
                    //print("📋 Hoạt động cho ngày \(dateFormatter.string(from: date)): \(activities.map { "\($0.activity) (ID: \($0.id))" })")
                }
            }
        }
    }
}
