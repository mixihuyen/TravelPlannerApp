import SwiftUI

struct TripDetailView: View {
    let tripId: Int
    @EnvironmentObject var viewModel: TripDetailViewModel
    @EnvironmentObject var tripViewModel: TripViewModel
    @EnvironmentObject var navManager: NavigationManager
    
    private var trip: TripModel? {
        tripViewModel.trips.first { $0.id == tripId }
    }
    
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            if let trip = trip {
                ScrollView {
                    VStack {
                        ZStack(alignment: .bottom) {
                            if let urlString = trip.imageCoverUrl, let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 200)
                                        .ignoresSafeArea()
                                        .mask(
                                            Rectangle()
                                                .fill(Color.retangleBackground)
                                                .frame(height: 200)
                                                .ignoresSafeArea()
                                        )
                                } placeholder: {
                                    Image("default_image")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 200)
                                        .ignoresSafeArea()
                                        .mask(
                                            Rectangle()
                                                .fill(Color.retangleBackground)
                                                .frame(height: 200)
                                                .ignoresSafeArea()
                                        )
                                }
                            } else {
                                Image("default_image")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .ignoresSafeArea()
                                    .mask(
                                        Rectangle()
                                            .fill(Color.retangleBackground)
                                            .frame(height: 200)
                                            .ignoresSafeArea()
                                    )
                            }
                            
                            Rectangle()
                                .fill(Color.retangleBackground)
                                .frame(height: 200)
                                .ignoresSafeArea()
                            HStack {
                                Image("detail")
                                    .resizable()
                                    .frame(width: 93, height: 101)
                                VStack(alignment: .leading) {
                                    Text(trip.name)
                                        .font(.system(size: 20))
                                        .bold()
                                        .foregroundColor(.white)
                                    Text("\(Formatter.formatDate1(trip.startDate)) → \(Formatter.formatDate1(trip.endDate))")
                                        .foregroundColor(.white)
                                        .font(.system(size: 12))
                                }
                                .padding(.top, 40)
                                Spacer()
                                Button(action: {
                                    navManager.path.append(Route.editTrip(trip: trip)) // Điều hướng đến EditTripView
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.white)
                                        .font(.system(size: 20))
                                        .padding()
                                        .background(Circle().fill(Color.gray.opacity(0.5)))
                                }
                                .padding(.top, 40)
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 40)
                        
                        HStack {
                            VStack(spacing: 20) {
                                if viewModel.isLoading && viewModel.tripDays.isEmpty {
                                    LottieView(animationName: "loading2")
                                        .frame(width: 100, height: 100)
                                        .padding(.top, 150)
                                } else if viewModel.tripDays.isEmpty {
                                    Text("Không có ngày nào trong chuyến đi")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16))
                                        .padding(.top, 150)
                                } else {
                                    ForEach(viewModel.tripDays, id: \.self) { date in
                                        Button {
                                            viewModel.getTripDayId(for: date) { tripDayId in
                                                guard let tripDayId = tripDayId else {
                                                    viewModel.showToast(message: "Không tìm thấy ngày chuyến đi")
                                                    return
                                                }
                                                let route = Route.activity(date: date, activities: viewModel.activities(for: date), trip: trip, tripDayId: tripDayId)
                                                navManager.path.append(route)
                                            }
                                        } label: {
                                            TripDayWidgetView(
                                                title: Formatter.formatDate2(date),
                                                activities: viewModel.activities(for: date),
                                                formatTime: Formatter.formatTime
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .id(viewModel.refreshTrigger)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 87)
                }
                .ignoresSafeArea()
                
                if viewModel.showToast, let toastMessage = viewModel.toastMessage {
                    VStack {
                        Spacer()
                        Text(toastMessage)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(10)
                            .padding(.bottom, 100)
                    }
                }
            } else {
                Text("Không tìm thấy chuyến đi")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
        }
        .onAppear {
            viewModel.fetchTripDays(completion: {
                print("📅 Đã làm mới tripDays khi TripDetailView xuất hiện")
            }, forceRefresh: false)
        }
    }
}
