import SwiftUI

struct TripCardView: View {
    let tripId: Int // Nhận tripId
    @EnvironmentObject var viewModel: TripViewModel // Lấy TripModel từ TripViewModel
    @EnvironmentObject var navManager: NavigationManager
    @StateObject private var participantViewModel = ParticipantViewModel()
    @State private var selectedUser: UserInformation?
    @State private var parentToastMessage = ""
    @State private var parentShowToast = false
    
    // Lấy TripModel từ TripViewModel
    private var trip: TripModel? {
        viewModel.trips.first { $0.id == tripId }
    }
    
    var body: some View {
        Group {
            if let trip = trip, tripId > 0 {
                GeometryReader { geo in
                    ZStack {
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
                                let currentUserId = UserDefaults.standard.integer(forKey: "userId")
                                let userRole = trip.tripParticipants?.first(where: { $0.userId == currentUserId })?.role ?? "Unknown"
                                HStack(spacing: 3) {
                                    Image(systemName: trip.isPublic ? "globe.europe.africa.fill" : "lock.fill")
                                        .foregroundColor(Color.white)
                                        .font(.system(size: 12))
                                    Text(Formatter.formatRole(userRole))
                                        .font(.caption)
                                        .foregroundColor(Color.pink)
                                }
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
                            VStack {
                                Image("cat")
                                    .resizable()
                                    .frame(width: 91, height: 100)
                                HStack(spacing: 0) {
                                    NavigationLink(destination: SearchUsersView(
                                        tripId: tripId,
                                        participantViewModel: participantViewModel,
                                        selectedUser: $selectedUser,
                                        parentToastMessage: $parentToastMessage,
                                        parentShowToast: $parentShowToast
                                    )) {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .font(.system(size: 30))
                                            .foregroundColor(.white)
                                    }
                                    
                                    ForEach(trip.tripParticipants?.prefix(2) ?? [], id: \.id) { participant in
                                        Circle()
                                            .fill(Color.pink)
                                            .frame(width: 30, height: 30)
                                            .overlay(
                                                Text(avatarInitials(for: participant))
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                    if (trip.tripParticipants?.count ?? 0) < 2 {
                                        ForEach(0..<(2 - (trip.tripParticipants?.count ?? 0)), id: \.self) { _ in
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
            } else {
                Text("Chuyến đi không hợp lệ")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
        }
        .onAppear {
            participantViewModel.fetchParticipants(tripId: tripId)
            if tripId <= 0 {
                print("⚠️ Cảnh báo: tripId không hợp lệ (\(tripId))")
            }
        }
    }
    
    private func avatarInitials(for participant: TripParticipant) -> String {
        let firstInitial = participant.userInformation?.firstName?.prefix(1) ?? ""
        let lastInitial = participant.userInformation?.lastName?.prefix(1) ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
}
