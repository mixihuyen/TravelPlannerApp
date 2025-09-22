import SwiftUI
import CoreImage.CIFilterBuiltins
import Network

struct MembersView: View {
    let tripId: Int // Thay trip: TripModel bằng tripId: Int
    @StateObject private var participantViewModel = ParticipantViewModel()
    @StateObject private var packingListViewModel: PackingListViewModel
    @State private var searchText = ""
    @State private var selectedUser: UserInformation?
    @State private var showSearchView = false
    @State private var toastMessage = ""
    @State private var showToast = false
    @State private var parentToastMessage = ""
    @State private var parentShowToast = false
    @State private var showLeaveConfirmation = false
    @State private var showRoleSelection = false
    @State private var selectedParticipant: Participant?
    @State private var showJoinAlert = false // Trạng thái cho thông báo join
    @State private var pendingTripId: Int? // Lưu tripId từ deep link
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var size
    
    init(tripId: Int, pendingTripId: Int? = nil) {
        self.tripId = tripId
        self._packingListViewModel = StateObject(wrappedValue: PackingListViewModel(tripId: tripId))
        self._pendingTripId = State(initialValue: pendingTripId)
    }
    
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            
            MainContentView(
                tripId: tripId,
                participantViewModel: participantViewModel,
                packingListViewModel: packingListViewModel,
                showSearchView: $showSearchView,
                selectedUser: $selectedUser,
                toastMessage: $toastMessage,
                showToast: $showToast,
                parentToastMessage: $parentToastMessage,
                parentShowToast: $parentShowToast,
                showLeaveConfirmation: $showLeaveConfirmation,
                showRoleSelection: $showRoleSelection,
                selectedParticipant: $selectedParticipant
            )
            .overlay(
                Group {
                    if participantViewModel.showToast, let message = participantViewModel.toastMessage, let type = participantViewModel.toastType {
                        ToastView(message: message, type: type)
                    }
                },
                alignment: .bottom
            )
            .frame(
                maxWidth: size == .regular ? 600 : .infinity,
                alignment: .center
            )
        }
        .onAppear {
            participantViewModel.fetchParticipants(tripId: tripId)
            packingListViewModel.fetchParticipants {
                print("✅ PackingListViewModel đã làm mới participants")
            }
            // Kiểm tra nếu có pendingTripId từ deep link
            if let tripId = pendingTripId {
                showJoinAlert = true
            }
        }
        .alert(isPresented: $showJoinAlert) {
            Alert(
                title: Text("Tham gia chuyến đi"),
                message: Text("Bạn có muốn tham gia chuyến đi này không?"),
                primaryButton: .default(Text("Chấp nhận")) {
                    if let tripId = pendingTripId {
                        participantViewModel.joinTrip(tripId: tripId) {
                            parentToastMessage = "Tham gia chuyến đi thành công!"
                            parentShowToast = true
                            pendingTripId = nil
                        }
                    }
                },
                secondaryButton: .cancel(Text("Từ chối")) {
                    pendingTripId = nil
                }
            )
        }
        .alert(isPresented: $showLeaveConfirmation) {
            Alert(
                title: Text("Rời nhóm"),
                message: Text("Bạn có chắc chắn muốn rời nhóm này không?"),
                primaryButton: .destructive(Text("Rời nhóm")) {
                    participantViewModel.leaveTrip(tripId: tripId, packingListViewModel: packingListViewModel) {
                        print("✅ User has left the trip")
                        parentToastMessage = "Đã rời nhóm thành công!"
                        parentShowToast = true
                        dismiss()
                    }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
        .actionSheet(isPresented: $showRoleSelection) {
            ActionSheet(
                title: Text("Chọn vai trò"),
                message: Text("Chọn vai trò mới cho \(selectedParticipant?.userInformation.username ?? "thành viên")"),
                buttons: [
                    .default(Text("Owner")) {
                        if let participant = selectedParticipant {
                            participantViewModel.editParticipantRole(tripId: tripId, participantId: participant.id, newRole: "owner") {
                                print("✅ Changed role to owner for participant ID: \(participant.id)")
                            }
                        }
                    },
                    .default(Text("Cashier")) {
                        if let participant = selectedParticipant {
                            participantViewModel.editParticipantRole(tripId: tripId, participantId: participant.id, newRole: "cashier") {
                                print("✅ Changed role to cashier for participant ID: \(participant.id)")
                            }
                        }
                    },
                    .default(Text("Member")) {
                        if let participant = selectedParticipant {
                            participantViewModel.editParticipantRole(tripId: tripId, participantId: participant.id, newRole: "member") {
                                print("✅ Changed role to member for participant ID: \(participant.id)")
                            }
                        }
                    },
                    .cancel()
                ]
            )
        }
    }
}

// MARK: - Main Content View
private struct MainContentView: View {
    let tripId: Int // Thay trip: TripModel bằng tripId: Int
    @ObservedObject var participantViewModel: ParticipantViewModel
    @ObservedObject var packingListViewModel: PackingListViewModel
    @Binding var showSearchView: Bool
    @Binding var selectedUser: UserInformation?
    @Binding var toastMessage: String
    @Binding var showToast: Bool
    @Binding var parentToastMessage: String
    @Binding var parentShowToast: Bool
    @Binding var showLeaveConfirmation: Bool
    @Binding var showRoleSelection: Bool
    @Binding var selectedParticipant: Participant?
    
    var body: some View {
        VStack {
            HeaderView(
                tripId: tripId,
                showSearchView: $showSearchView,
                participantCount: participantViewModel.participants.count,
                participantViewModel: participantViewModel,
                packingListViewModel: packingListViewModel,
                showLeaveConfirmation: $showLeaveConfirmation
            )
            ParticipantsListView(
                participantViewModel: participantViewModel,
                packingListViewModel: packingListViewModel,
                tripId: tripId,
                selectedParticipant: $selectedParticipant,
                showRoleSelection: $showRoleSelection
            )
            NavigationLink(
                destination: SearchUsersView(
                    tripId: tripId,
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
    let tripId: Int // Thay trip: TripModel bằng tripId: Int
    @Binding var showSearchView: Bool
    let participantCount: Int
    @ObservedObject var participantViewModel: ParticipantViewModel
    @ObservedObject var packingListViewModel: PackingListViewModel
    @Binding var showLeaveConfirmation: Bool
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    showSearchView = true
                }) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            .padding(.top, 40)
            
            HStack {
                Text("Danh sách thành viên (\(participantCount))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Button(action: {
                    participantViewModel.copyDeepLink(tripId: tripId)
                    participantViewModel.showToast(message: "Đã sao chép liên kết mời!", type: .success)
                }) {
                    Image(systemName: "link")
                        .font(.system(size: 16, weight: .bold ))
                        .foregroundColor(.white)
                }
                Spacer()
                
                let currentUserId = UserDefaults.standard.integer(forKey: "userId")
                let userRole = participantViewModel.participants.first(where: { $0.userId == currentUserId })?.role ?? "Unknown"
                
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
            .padding(.vertical, 20)
        }
        .padding(.horizontal)
    }
}

// MARK: - Participants List View
private struct ParticipantsListView: View {
    @ObservedObject var participantViewModel: ParticipantViewModel
    @ObservedObject var packingListViewModel: PackingListViewModel
    let tripId: Int // Thay trip: TripModel bằng tripId: Int
    @Binding var selectedParticipant: Participant?
    @Binding var showRoleSelection: Bool
    
    var body: some View {
        let currentUserId = UserDefaults.standard.integer(forKey: "userId")
        let userRole = participantViewModel.participants.first(where: { $0.userId == currentUserId })?.role ?? "Unknown"
        
        List {
            ForEach(Array(participantViewModel.participants.enumerated()), id: \.1.id) { index, participant in
                MemberRow(member: participant)
                    .frame(minHeight: 44)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(index % 2 == 0 ? Color("dark") : Color("light"))
                    .onTapGesture {
                        if userRole == "owner" && participant.userInformation.id != currentUserId {
                            selectedParticipant = participant
                            showRoleSelection = true
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if userRole == "owner" && participant.userInformation.id != currentUserId {
                            Button(role: .destructive) {
                                participantViewModel.removeParticipant(
                                    tripId: tripId,
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
