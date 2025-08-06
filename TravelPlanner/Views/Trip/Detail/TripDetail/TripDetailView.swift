import SwiftUI

struct TripDetailView: View {
    let trip: TripModel
    
    @StateObject var viewModel: TripDetailViewModel
    @EnvironmentObject var navManager: NavigationManager
    init(trip: TripModel) {
        self.trip = trip
        _viewModel = StateObject(wrappedValue: TripDetailViewModel(trip: trip))
    }
    
    
    var body: some View {
            ZStack {
                Color.background
                    .ignoresSafeArea()
                ScrollView {
                    VStack {
                        ZStack (alignment: .bottom) {
                            //                            if let data = trip.image, let uiImage = UIImage(data: data) {
                            //                                Image(uiImage: uiImage)
                            //                                    .resizable()
                            //                                    .scaledToFill()
                            //                                    .frame(height: 200)
                            //                                    .ignoresSafeArea()
                            //                                    .mask(Rectangle()
                            //                                        .fill(Color.retangleBackground)
                            //                                        .frame(height: 200)
                            //                                        .ignoresSafeArea())
                            //
                            //                            } else {
                            Image("default_image")
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .ignoresSafeArea()
                                .mask(Rectangle()
                                    .fill(Color.retangleBackground)
                                    .frame(height: 200)
                                    .ignoresSafeArea())
                            //}
                            Rectangle()
                                .fill(Color.retangleBackground)
                                .frame(height: 200)
                                .ignoresSafeArea()
                            HStack {
                                Image("detail")
                                    .resizable()
                                    .frame(width: 93, height: 101)
                                VStack (alignment: .leading) {
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
                            }
                            .padding(.horizontal, 20)
                            
                            
                            
                        }
                        .padding(.bottom, 40)
                        Spacer()
                        HStack {
                            VStack(spacing: 20) {
                                if viewModel.isLoading {
                                    LottieView(animationName: "loading2")
                                        .frame(width: 100, height: 100)
                                        .padding(.top, 150)
                                } else {
                                    ForEach(viewModel.tripDays, id: \.self) { date in
                                        Button {
                                            let route = Route.activity(date: date, activities: viewModel.activities(for: date), trip: trip)
                                            navManager.path.append(route)
                                        } label: {
                                            TripDayWidgetView(
                                                title: Formatter.formatDate2(date),
                                                activities: viewModel.activities(for: date),
                                                formatTime: Formatter.formatTime
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                    }
                    
                }
                .padding(.bottom, 87)
                .ignoresSafeArea()
            }

        
        
    }
}
