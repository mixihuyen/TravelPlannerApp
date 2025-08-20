import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var navManager: NavigationManager
    let date: Date
    let trip: TripModel
    let tripDayId: Int
    @EnvironmentObject var viewModel: TripDetailViewModel

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
                        let currentUserId = UserDefaults.standard.integer(forKey: "userId")
                        let userRole = trip.tripParticipants?.first(where: { $0.userId == currentUserId })?.role ?? "Unknown"
                        
                        if userRole != "member" {
                            Button(action: {
                                navManager.go(to: .addActivity(date: date, trip: trip, tripDayId: tripDayId))
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
                                        let currentUserId = UserDefaults.standard.integer(forKey: "userId")
                                        let userRole = trip.tripParticipants?.first(where: { $0.userId == currentUserId })?.role ?? "Unknown"
                                        
                                        if userRole != "member" {
                                            navManager.go(to: .editActivity(date: date, activity: activity, trip: trip, tripDayId: tripDayId))
                                        }
                                    }) {
                                        ActivityCardView(activity: activity)
                                    }
                                }
                            }
                            .id(viewModel.refreshTrigger)
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
            print("📅 Ngày được chọn: \(dateFormatter.string(from: date)), tripDayId: \(tripDayId)")
            let activities = viewModel.activities(for: date)
            print("📋 Hoạt động cho ngày \(dateFormatter.string(from: date)): \(activities.map { "\($0.activity) (ID: \($0.id))" })")
        }
    }
}
