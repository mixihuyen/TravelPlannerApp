
import SwiftUI

struct TripView: View {
    @EnvironmentObject private var viewModel : TripViewModel
    @Environment(\.horizontalSizeClass) var size
    @EnvironmentObject var navManager: NavigationManager
    
    var columns: [GridItem] {
        if size == .compact {
            return [GridItem(.flexible())]
        }
        else {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack{
                // MARK: Background Color
                Color.background
                    .ignoresSafeArea()
                VStack{
                    ZStack (alignment: .center) {
                        Rectangle()
                            .fill(Color.background2)
                            .ignoresSafeArea()
                        
                        HStack{
                            Text("Travel Planner")
                                .font(.system(size: 32, weight: .bold, design: .default))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: {
                                navManager.go(to:.createTrip)
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
                    
                    CustomPullToRefresh(threshold: 120, holdDuration: 0.3, content: {
                        VStack{
                            LazyVGrid(columns: columns, spacing: 50) {
                                if viewModel.isLoading && !viewModel.isRefreshing {
                                    LottieView(animationName: "loading2")
                                        .frame(width: 100, height: 100)
                                        .padding(.top, 250)
                                } else {
                                    ForEach(viewModel.trips) { trip in
                                        NavigationLink(value: Route.tabBarView(trip: trip)) {
                                                                    TripCardView(trip: trip)
                                                                        .frame(maxWidth: .infinity)
                                                                }
                                                                .buttonStyle(PlainButtonStyle())
                                        
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
                    },
                    onRefresh: {
                        viewModel.refreshTrips() // hoặc task bạn muốn gọi lại
                    })
                    
                    
                    
                }
            }
            .navigationBarBackButtonHidden(true)
            
            
        }
        .environmentObject(viewModel)
        .onAppear {
            viewModel.fetchTrips()
        }
        .onChange(of: viewModel.showToast) { newValue in
                    if newValue {
                        print("📢 Toast hiển thị trong TripView: \(viewModel.toastMessage ?? "nil")")
                    }
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
    
}
