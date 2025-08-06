import SwiftUI

struct MembersView: View {
    var trip: TripModel
    @StateObject private var participantViewModel = ParticipantViewModel()
    @StateObject private var packingListViewModel = PackingListViewModel(tripId: 1) // Thêm PackingListViewModel
    @State private var searchText = ""
    @State private var selectedUser: User?
    @State private var showSearchView = false
    @State private var toastMessage = ""
    @State private var showToast = false
    @State private var parentToastMessage = ""
    @State private var parentShowToast = false
    
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            
            MainContentView(
                trip: trip,
                participantViewModel: participantViewModel,
                packingListViewModel: packingListViewModel, // Truyền packingListViewModel
                showSearchView: $showSearchView,
                selectedUser: $selectedUser,
                toastMessage: $toastMessage,
                showToast: $showToast,
                parentToastMessage: $parentToastMessage,
                parentShowToast: $parentShowToast
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
            packingListViewModel.fetchParticipants { // Đảm bảo PackingListViewModel cũng làm mới dữ liệu
                print("✅ PackingListViewModel đã làm mới participants")
            }
        }
    }
}

// MARK: - Main Content View
private struct MainContentView: View {
    let trip: TripModel
    @ObservedObject var participantViewModel: ParticipantViewModel
    @ObservedObject var packingListViewModel: PackingListViewModel // Thêm tham số
    @Binding var showSearchView: Bool
    @Binding var selectedUser: User?
    @Binding var toastMessage: String
    @Binding var showToast: Bool
    @Binding var parentToastMessage: String
    @Binding var parentShowToast: Bool
    
    var body: some View {
        VStack {
            HeaderView(showSearchView: $showSearchView, participantCount: participantViewModel.participants.count)
            ParticipantsListView(
                participantViewModel: participantViewModel,
                packingListViewModel: packingListViewModel, // Truyền packingListViewModel
                tripId: trip.id
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
    @Binding var showSearchView: Bool
    let participantCount: Int
    
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
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal)
    }
}

// MARK: - Participants List View
private struct ParticipantsListView: View {
    @ObservedObject var participantViewModel: ParticipantViewModel
    @ObservedObject var packingListViewModel: PackingListViewModel // Thêm tham số
    let tripId: Int
    
    var body: some View {
        List {
            ForEach(Array(participantViewModel.participants.enumerated()), id: \.1.id) { index, participant in
                MemberRow(member: participant)
                    .frame(minHeight: 44)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(index % 2 == 0 ? Color("dark") : Color("light"))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            participantViewModel.removeParticipant(
                                tripId: tripId,
                                tripParticipantId: participant.id,
                                packingListViewModel: packingListViewModel // Truyền packingListViewModel
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
