import SwiftUI

struct ActivityView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var navManager: NavigationManager
    let date: Date
    @State var activities: [TripActivity]
    let trip: TripModel
    @EnvironmentObject var viewModel: TripDetailViewModel
    
    init(date: Date, activities: [TripActivity], trip: TripModel) {
        self.date = date
        self._activities = State(initialValue: activities)
        self.trip = trip
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.background.ignoresSafeArea()
            
            ScrollView {
                HStack{
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
                            navManager.go(to: .addActivity(date: date, trip: trip))
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
                        if activities.isEmpty {
                            VStack(spacing: 8) {
                                Image("empty")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.gray)
                                
                                Text("Chưa có hoạt động nào")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                        } else {
                            VStack(spacing: 16) {
                                ForEach(activities) { activity in
                                    Button(action: {
                                        navManager.go(to: .editActivity(date: date,activity: activity, trip: trip ))
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
            viewModel.fetchTripDays(completion: {
                let newActivities = viewModel.activities(for: date)
                print("📋 Danh sách hoạt động khi view xuất hiện: \(newActivities.map { "\($0.activity) (ID: \($0.id))" })")
                self.activities = newActivities
            }, forceRefresh: true)
        }
    }
}
