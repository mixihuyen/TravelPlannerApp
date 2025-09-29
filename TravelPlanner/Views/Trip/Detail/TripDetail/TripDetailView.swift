import SwiftUI

struct TripDetailView: View {
    let tripId: Int
    @EnvironmentObject var viewModel: TripViewModel // Lấy TripModel
    @EnvironmentObject var tripDetailViewModel: TripDetailViewModel // Lấy TripDay
    @EnvironmentObject var navManager: NavigationManager // Điều hướng
    @Environment(\.horizontalSizeClass) var size // Kích thước giao diện
    @StateObject private var activityViewModel: ActivityViewModel
    
    
    private var trip: TripModel? {
        viewModel.trips.first { $0.id == tripId }
    }
    
    init(tripId: Int) {
            self.tripId = tripId
            self._activityViewModel = StateObject(wrappedValue: ActivityViewModel(tripId: tripId))
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
                            HStack(alignment: .bottom) {
                                Image("detail")
                                    .resizable()
                                    .frame(width: 93, height: 101)
                                VStack(alignment: .leading) {
                                    Text(trip.name)
                                        .font(.system(size: 20))
                                        .bold()
                                        .foregroundColor(.white)
                                    
                                    HStack {
                                        Text("\(Formatter.formatDate1(trip.startDate)) → \(Formatter.formatDate1(trip.endDate))")
                                            .foregroundColor(.white)
                                            .font(.system(size: 12))
                                        Image(systemName: trip.isPublic ? "globe.europe.africa.fill" : "lock.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 12))
                                    }
                                }
                                Spacer()
                                Button(action: {
                                    navManager.path.append(Route.editTrip(trip: trip))
                                }) {
                                    Image(systemName: "square.and.pencil.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 24))
                                }
                            }
                            .frame(
                                maxWidth: size == .regular ? 600 : .infinity,
                                alignment: .center
                            )
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 40)
                        
                            VStack(spacing: 20) {
                                 
                                    ForEach(tripDetailViewModel.getTripDays(), id: \.id) { tripDay in
                                        Button {
                                            guard tripId > 0, tripDay.id > 0 else {
                                                tripDetailViewModel.showToast(message: "ID chuyến đi hoặc ngày không hợp lệ", type: .error)
                                                return
                                            }
                                            print("📋 Navigating to ActivityView with tripId: \(tripId), tripDayId: \(tripDay.id)")
                                            navManager.path.append(Route.activity(tripId: tripId, tripDayId: tripDay.id))
                                        } label: {
                                            TripDayWidgetView(
                                                title: Formatter.dateOnlyFormatter.date(from: tripDay.day).map { Formatter.formatDate2($0) } ?? tripDay.day,
                                                activities: tripDetailViewModel.getActivities(for: tripDay.id),
                                                formatTime: Formatter.formatTime
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .contentShape(Rectangle())
                                    }
                                    .id(tripDetailViewModel.refreshTrigger)
                                
                            }
                        .frame(
                            maxWidth: size == .regular ? 600 : .infinity,
                            alignment: .center
                        )
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 87)
                }
                .ignoresSafeArea()
                
                .overlay(
                    Group {
                        if tripDetailViewModel.showToast, let message = tripDetailViewModel.toastMessage, let type = tripDetailViewModel.toastType {
                            ToastView(message: message, type: type)
                        }
                    },
                    alignment: .bottom
                )
            } 
            if tripDetailViewModel.isLoading && tripDetailViewModel.getTripDays().isEmpty {
                VStack {
                    LottieView(animationName: "loading2")
                        .frame(width: 50, height: 50)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tripDetailViewModel.getTripDays().isEmpty {
                Text("Không có ngày nào trong chuyến đi")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                    .padding(.top, 150)
            }
        }
        .onAppear {
            tripDetailViewModel.fetchTripDays(completion: {
                print("📅 Đã làm mới tripDays khi TripDetailView xuất hiện")
            }, forceRefresh: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TripUpdated"))) { notification in
            if let updatedTripId = notification.userInfo?["tripId"] as? Int, updatedTripId == tripId {
                print("🔄 Nhận thông báo TripUpdated cho tripId=\(tripId), làm mới tripDays")
                tripDetailViewModel.fetchTripDays(completion: {
                    print("📅 Đã làm mới tripDays sau khi cập nhật chuyến đi")
                }, forceRefresh: true)
            }
        }
    }
}

