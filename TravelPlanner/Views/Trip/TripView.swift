import SwiftUI

struct TripView: View {
    @EnvironmentObject private var viewModel: TripViewModel
    @Environment(\.horizontalSizeClass) var size
    @EnvironmentObject var navManager: NavigationManager
    @EnvironmentObject var navCoor: NavigationCoordinator
    
    var columns: [GridItem] {
        if size == .compact {
            return [GridItem(.flexible())]
        } else {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // MARK: Màu nền
                Color.background
                    .ignoresSafeArea()
                VStack {
                    ZStack(alignment: .center) {
                        Rectangle()
                            .fill(Color.background2)
                            .ignoresSafeArea()
                        
                        HStack {
                            Text("Travel Planner")
                                .font(.system(size: 32, weight: .bold, design: .default))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: {
                                navManager.go(to: .createTrip)
                            }) {
                                Image(systemName: "text.badge.plus")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 20)
                    }
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    
                    ZStack {
                        if viewModel.trips.isEmpty && !viewModel.isLoading {
                            VStack(spacing: 10) {
                                Image("empty")
                                    .resizable()
                                    .frame(width: 150, height: 150)
                                    .foregroundColor(.gray)
                                
                                Text("Không có chuyến đi nào!")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .semibold))
                                    .multilineTextAlignment(.center)
                                
                                Text("Hãy bắt đầu lên kế hoạch để những chuyến đi của bạn thêm thuận lợi!")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 13))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            CustomPullToRefresh(threshold: 120, holdDuration: 0.3, content: {
                                VStack {
                                    if viewModel.isLoading && !viewModel.isRefreshing {
                                        LottieView(animationName: "loading2")
                                            .frame(width: 100, height: 100)
                                            .padding(.top, 250)
                                    } else {
                                        LazyVGrid(columns: columns, spacing: 50) {
                                            ForEach(viewModel.trips) { trip in
                                                Button {
                                                    print("Trip ID: \(trip.id)")
                                                    guard trip.id > 0 else {
                                                        viewModel.showToast(message: "ID chuyến đi không hợp lệ", type: .error)
                                                        return
                                                    }
                                                    navManager.path.append(Route.tabBarView(tripId: trip.id))
                                                } label: {
                                                    TripCardView(tripId: trip.id)
                                                        .frame(maxWidth: .infinity)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                .contentShape(Rectangle())
                                                
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.bottom, 50)
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                                .frame(maxWidth: 900)
                                .frame(maxWidth: .infinity)
                            }, onRefresh: {
                                viewModel.refreshTrips()
                            })
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
        }
        .environmentObject(viewModel)
        .onAppear {
            viewModel.fetchTrips()
        }
        .onChange(of: navCoor.shouldRefreshTrips) { shouldRefresh in
            if shouldRefresh {
                viewModel.fetchTrips(forceRefresh: true) {
                    navCoor.shouldRefreshTrips = false
                }
            }
        }
        .overlay(
            Group {
                if viewModel.showToast, let message = viewModel.toastMessage, let type = viewModel.toastType {
                    ToastView(message: message, type: type)
                }
            },
            alignment: .bottom
        )
    }
}
