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
                            if let imageData = trip.imageCoverData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
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
                                    HStack{
                                        Image(systemName: "globe.europe.africa.fill")
                                            .foregroundColor(Color.white)
                                            .frame(width: 16, height: 16)
                                        Text("Công khai")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    }
                                    HStack (alignment: .bottom){
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(Color.white)
                                            .frame(width: 16, height: 16)
                                        Text("Riêng tư")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    }
                                    
                                    
                                    
                                    Text(trip.name)
                                        .font(.system(size: 20))
                                        .bold()
                                        .foregroundColor(.white)
                                    Text("\(Formatter.formatDate1(trip.startDate)) → \(Formatter.formatDate1(trip.endDate))")
                                        .foregroundColor(.white)
                                        .font(.system(size: 12))
                                }
                                Spacer()
                                Button(action: {
                                    navManager.path.append(Route.editTrip(trip: trip)) // Điều hướng đến EditTripView
                                }) {
                                    Image(systemName: "square.and.pencil.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 24))
                                }
                            }
                            .padding(.horizontal)
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
                                                    viewModel.showToast(message: "Không tìm thấy ngày chuyến đi", type: .error)
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
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 87)
                }
                .ignoresSafeArea()
                
                .overlay(
                    Group {
                        if viewModel.showToast, let message = viewModel.toastMessage, let type = viewModel.toastType {
                            ToastView(message: message, type: type)
                        }
                    },
                    alignment: .bottom
                )
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
        .onChange(of: tripViewModel.trips) { newTrips in
            print("🔄 Trips đã thay đổi, tìm trip ID: \(tripId)")
            if let updatedTrip = newTrips.first(where: { $0.id == tripId }) {
                print("🔍 Trip được tìm thấy: startDate: \(updatedTrip.startDate), endDate: \(updatedTrip.endDate)")
            } else {
                print("❌ Không tìm thấy trip với ID: \(tripId)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TripUpdated"))) { notification in
            if let tripId = notification.userInfo?["tripId"] as? Int, tripId == self.tripId {
                print("🔄 Nhận thông báo TripUpdated cho tripId=\(tripId), làm mới tripDays")
                viewModel.fetchTripDays(completion: {
                    print("📅 Đã làm mới tripDays sau khi cập nhật chuyến đi")
                }, forceRefresh: true)
            }
        }
    }
}
