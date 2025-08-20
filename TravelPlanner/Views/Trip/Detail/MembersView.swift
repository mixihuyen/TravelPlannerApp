import SwiftUI

struct MembersView: View {
    var trip: TripModel
    @StateObject private var participantViewModel = ParticipantViewModel()
    @StateObject private var packingListViewModel: PackingListViewModel
    @State private var searchText = ""
    @State private var selectedUser: User?
    @State private var showSearchView = false
    @State private var toastMessage = ""
    @State private var showToast = false
    @State private var parentToastMessage = ""
    @State private var parentShowToast = false
    @State private var showLeaveConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    init(trip: TripModel) {
        self.trip = trip
        self._packingListViewModel = StateObject(wrappedValue: PackingListViewModel(tripId: trip.id))
    }
    
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            
            MainContentView(
                trip: trip,
                participantViewModel: participantViewModel,
                packingListViewModel: packingListViewModel,
                showSearchView: $showSearchView,
                selectedUser: $selectedUser,
                toastMessage: $toastMessage,
                showToast: $showToast,
                parentToastMessage: $parentToastMessage,
                parentShowToast: $parentShowToast,
                showLeaveConfirmation: $showLeaveConfirmation
            )
            .overlay(
                Group {
                    if participantViewModel.showToast, let message = participantViewModel.toastMessage {
                        SuccessToastView(message: message)
                    }
                    if parentShowToast {
                        SuccessToastView(message: parentToastMessage)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    parentShowToast = false
                                }
                            }
                    }
                },
                alignment: .bottom
            )
        }
        .onAppear {
            participantViewModel.fetchParticipants(tripId: trip.id)
            packingListViewModel.fetchParticipants {
                print("✅ PackingListViewModel đã làm mới participants")
            }
        }
        .alert(isPresented: $showLeaveConfirmation) {
            Alert(
                title: Text("Rời nhóm"),
                message: Text("Bạn có chắc chắn muốn rời nhóm này không?"),
                primaryButton: .destructive(Text("Rời nhóm")) {
                    participantViewModel.leaveTrip(tripId: trip.id, packingListViewModel: packingListViewModel) {
                        print("✅ User has left the trip")
                        parentToastMessage = "Đã rời nhóm thành công!"
                        parentShowToast = true
                        dismiss()
                    }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }
}

// MARK: - Main Content View
private struct MainContentView: View {
    let trip: TripModel
    @ObservedObject var participantViewModel: ParticipantViewModel
    @ObservedObject var packingListViewModel: PackingListViewModel
    @Binding var showSearchView: Bool
    @Binding var selectedUser: User?
    @Binding var toastMessage: String
    @Binding var showToast: Bool
    @Binding var parentToastMessage: String
    @Binding var parentShowToast: Bool
    @Binding var showLeaveConfirmation: Bool
    
    var body: some View {
        VStack {
            HeaderView(
                trip: trip,
                showSearchView: $showSearchView,
                participantCount: participantViewModel.participants.count,
                participantViewModel: participantViewModel,
                packingListViewModel: packingListViewModel,
                showLeaveConfirmation: $showLeaveConfirmation
            )
            ParticipantsListView(
                participantViewModel: participantViewModel,
                packingListViewModel: packingListViewModel,
                trip: trip
            )
            NavigationLink(
                destination: SearchUsersView(
                    trip: trip,
                    participantViewModel: participantViewModel,
                    selectedUser: $selectedUser,
                    parentToastMessage: $parentToastMessage,
                    parentShowToast: $parentShowToast
                ),
                isActive: $showSearchView
            ) {
                EmptyView()
            }
            .hidden()
        }
    }
}

// MARK: - Header View
private struct HeaderView: View {
    let trip: TripModel
    @Binding var showSearchView: Bool
    let participantCount: Int
    @ObservedObject var participantViewModel: ParticipantViewModel
    @ObservedObject var packingListViewModel: PackingListViewModel
    @Binding var showLeaveConfirmation: Bool
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "qrcode")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
                Button(action: {
                    showSearchView = true
                }) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(.vertical, 30)
            
            HStack {
                Text("Danh sách thành viên (\(participantCount))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                
                let currentUserId = UserDefaults.standard.integer(forKey: "userId")
                let userRole = trip.tripParticipants?.first(where: { $0.userId == currentUserId })?.role ?? "Unknown"
                
                if userRole != "owner" {
                    Button(action: {
                        showLeaveConfirmation = true
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.forward.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal)
    }
}

// MARK: - Participants List View
private struct ParticipantsListView: View {
    @ObservedObject var participantViewModel: ParticipantViewModel
    @ObservedObject var packingListViewModel: PackingListViewModel
    let trip: TripModel
    
    var body: some View {
        let currentUserId = UserDefaults.standard.integer(forKey: "userId")
        let userRole = trip.tripParticipants?.first(where: { $0.userId == currentUserId })?.role ?? "Unknown"
        
        List {
            ForEach(Array(participantViewModel.participants.enumerated()), id: \.1.id) { index, participant in
                MemberRow(member: participant)
                    .frame(minHeight: 44)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(index % 2 == 0 ? Color("dark") : Color("light"))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if userRole == "owner" && participant.user.id != currentUserId {
                            Button(role: .destructive) {
                                participantViewModel.removeParticipant(
                                    tripId: trip.id,
                                    tripParticipantId: participant.id,
                                    packingListViewModel: packingListViewModel
                                ) {
                                    print("✅ Hoàn tất xóa participant trong giao diện")
                                }
                            } label: {
                                Label("Xóa", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
