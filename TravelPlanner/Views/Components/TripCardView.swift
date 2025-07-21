import SwiftUI

struct TripCardView: View {
    var trip : TripModel
    
    var body: some View {
        GeometryReader { geo in
            ZStack{
//                if let data = trip.image, let uiImage = UIImage(data: data) {
//                    Image(uiImage: uiImage)
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: geo.size.width, height: 106)
//                        .mask(
//                            TripCard()
//                                .frame(width: geo.size.width, height: 106)
//                        )
//                    
//                } else {
                    Image("default_image")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: 106)
                        .mask(
                            TripCard()
                                .frame(width: geo.size.width, height: 106)
                        )
                //}
                
                TripCard()
                    .fill(Color.tripBackground)
                    .frame(width: geo.size.width, height: 106)
                HStack {
                    VStack(alignment: .leading) {
                        Text(trip.tripParticipants?.first?.role ?? "Unknown")
                            .font(.caption)
                            .foregroundColor(Color.pink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.background.opacity(0.8))
                            .cornerRadius(20)
                        Text(trip.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.white)
                            .lineLimit(1)
                                .truncationMode(.tail)
                        Text("\(Formatter.formatDate1(trip.startDate)) → \(Formatter.formatDate1(trip.endDate))")
                            .font(.caption)
                            .foregroundColor(Color.white)
                    }
                    .padding(.horizontal, 15)
                    .padding(.top, -20)
                    Spacer()
                    VStack{
                        Image("cat")
                            .resizable()
                            .frame(width: 91, height: 100)
                        HStack(spacing: 0){
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                            Image("avt")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                            Image("avt")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                        }
                        
                    }
                    .padding(.bottom, 20)
                    
                    
                }
            }
            
        }
        .frame(height: 106)
        .padding(.horizontal, 10)
    }
}
