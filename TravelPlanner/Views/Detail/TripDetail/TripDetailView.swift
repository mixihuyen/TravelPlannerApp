import SwiftUI

struct TripDetailView: View {
    let trip: TripModel
    
    @StateObject var viewModel: TripDetailViewModel
    init(trip: TripModel) {
        self.trip = trip
        _viewModel = StateObject(wrappedValue: TripDetailViewModel(trip: trip))
    }
    
    
    var body: some View {
        NavigationStack{
            ZStack {
                Color.background
                    .ignoresSafeArea()
                ScrollView {
                    VStack {
                        ZStack (alignment: .bottom) {
                            if let data = trip.image, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .ignoresSafeArea()
                                    .mask(Rectangle()
                                        .fill(Color.retangleBackground)
                                        .frame(height: 200)
                                        .ignoresSafeArea())
                                
                            } else {
                                Image("default_image")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .ignoresSafeArea()
                                    .mask(Rectangle()
                                        .fill(Color.retangleBackground)
                                        .frame(height: 200)
                                        .ignoresSafeArea())
                            }
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
                                    Text("\(trip.startDate) → \(trip.endDate)")
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
                                    ForEach(viewModel.tripDays, id: \.self) { date in
                                        NavigationLink(destination: ActivityView(date: date, activities: viewModel.activities(for: date))) {
                                            TripDayWidgetView(
                                                title: viewModel.formattedDate(date),
                                                activities: viewModel.activities(for: date)
                                            )
                                            
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    
                                    
                                    
                                    
                                
                            }
                            
                        }
                        .padding(.horizontal, 20)
                        
                    }
                    
                }
                .ignoresSafeArea()
            }
        }
        
    }
}
