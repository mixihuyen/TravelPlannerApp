import SwiftUI

struct TripCardView: View {
    var trip : TripModel
    @EnvironmentObject var navManager: NavigationManager
    @StateObject private var participantViewModel = ParticipantViewModel()
    @EnvironmentObject var tripViewModel: TripViewModel
    @State private var selectedUser: User?
    @State private var parentToastMessage = ""
    @State private var parentShowToast = false
    
    var body: some View {
        Group{
            
            
            GeometryReader { geo in
                ZStack{
                    if let imageData = trip.imageCoverData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: 106)
                            .mask(
                                TripCard()
                                    .frame(width: geo.size.width, height: 106)
                            )
                   
                    } else {
                        Image("default_image")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: 106)
                            .mask(
                                TripCard()
                                    .frame(width: geo.size.width, height: 106)
                            )
                    }
                    
                    TripCard()
                        .fill(Color.tripBackground)
                        .frame(width: geo.size.width, height: 106)
                    HStack {
                        VStack(alignment: .leading) {
                            HStack{
                                let currentUserId = UserDefaults.standard.integer(forKey: "userId")
                                let userRole = trip.tripParticipants?.first(where: { $0.userId == currentUserId })?.role ?? "Unknown"
                                Text(userRole)
                                    .font(.caption)
                                    .foregroundColor(Color.pink)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.background.opacity(0.8))
                                    .cornerRadius(20)
                                
                                Image(systemName: "globe.europe.africa.fill")
                                    .foregroundColor(Color.white)
                                    .frame(width: 16, height: 16)
                                
                                Image(systemName: "lock.fill")
                                    .foregroundColor(Color.white)
                                    .frame(width: 16, height: 16)
                                
                            }
                            
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
                                NavigationLink(destination: SearchUsersView(
                                    trip: trip,
                                    participantViewModel: participantViewModel,
                                    selectedUser: $selectedUser,
                                    parentToastMessage: $parentToastMessage,
                                    parentShowToast: $parentShowToast
                                )) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }
                                
                                ForEach(participantViewModel.participants.prefix(2), id: \.id) { participant in
                                    Circle()
                                        .fill(Color.pink)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Text(avatarInitials(for: participant))
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                }
                                // Nếu không đủ 2 thành viên, thêm placeholder
                                if participantViewModel.participants.count < 2 {
                                    ForEach(0..<(2 - participantViewModel.participants.count), id: \.self) { _ in
                                        Circle()
                                            .fill(Color.gray.opacity(0.5))
                                            .frame(width: 30, height: 30)
                                            .overlay(
                                                Text("??")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                }
                            }
                            
                        }
                        .padding(.bottom, 20)
                        
                        
                    }
                }
                
            }
            .frame(height: 106)
            .padding(.horizontal, 10)
        }
        .onAppear {
            participantViewModel.fetchParticipants(tripId: trip.id)
        }
        
    }
    private func avatarInitials(for participant: Participant) -> String {
        let firstInitial = participant.user.firstName?.prefix(1) ?? ""
        let lastInitial = participant.user.lastName?.prefix(1) ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
}



