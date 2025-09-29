import SwiftUI

struct TripView: View {
    @EnvironmentObject private var viewModel: TripViewModel
    @Environment(\.horizontalSizeClass) var size
    @EnvironmentObject var navManager: NavigationManager
    @EnvironmentObject var navCoor: NavigationCoordinator
    @State private var shouldShowEmptyState: Bool = false
    
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
                    // MARK: Header
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
                    
                    // MARK: Content
                    ZStack {
                        if !viewModel.trips.isEmpty && !viewModel.isLoading{
                            CustomPullToRefresh(threshold: 120, holdDuration: 0.3, content: {
                                VStack {
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
                        // MARK: Loading Overlay
                        if viewModel.isLoading  {
                            VStack {
                                LottieView(animationName: "loading2")
                                    .frame(width: 50, height: 50)
                            }
                        }
                        if shouldShowEmptyState && viewModel.trips.isEmpty && !viewModel.isLoading {
                            VStack(spacing: 10) {
                                Image("empty")
                                    .resizable()
                                    .frame(width: 100, height: 100)
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
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                }
                
                
            }
            .navigationBarBackButtonHidden(true)
        }
        .environmentObject(viewModel)
        .onAppear {
                    if viewModel.trips.isEmpty && !viewModel.isLoading {
                        print("🚀 TripView onAppear: Gọi fetchTrips")
                        viewModel.fetchTrips()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.shouldShowEmptyState = true
                        }
                    }
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
                if viewModel.showToast,
                   let message = viewModel.toastMessage,
                   let type = viewModel.toastType {
                    ToastView(message: message, type: type)
                }
            },
            alignment: .bottom
        )
    }
}
