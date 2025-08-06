import SwiftUI

struct SearchUsersView: View {
    @Environment(\.dismiss) var dismiss
    var trip: TripModel
    @ObservedObject var participantViewModel: ParticipantViewModel
    @Binding var selectedUser: User?
    @Binding var parentToastMessage: String
    @Binding var parentShowToast: Bool
    
    @State private var searchText = ""
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""
    @State private var debounceTask: DispatchWorkItem?
    @State private var selectedParticipants: [User] = []
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color.background
                    .ignoresSafeArea()
                
                VStack {
                    HStack(spacing: 20) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                        }
                        Text("Chọn người dùng")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.bottom, 20)
                    
                    // Search Bar
                    HStack {
                        CustomTextField(
                            placeholder: "Tìm kiếm username",
                            text: $searchText,
                            keyboardType: .default,
                            autocapitalization: .never,
                            disableAutocorrection: true,
                            showClearButton: true,
                            onClear: {
                                participantViewModel.searchResults = []
                            },
                            showIcon: true,
                            iconName: "magnifyingglass"
                        )
                        .onChange(of: searchText) { query in
                            debounceSearch(query: query)
                        }
                    }
                    .padding(.bottom, 20)
                    
                    // Invited Members Section
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Thành viên được mời (\(selectedParticipants.count))")
                                .foregroundColor(.white)
                            Spacer()
                            if !selectedParticipants.isEmpty {
                                Text("Bỏ chọn tất cả")
                                    .font(.system(size: 14))
                                    .foregroundColor(.pink)
                                    .underline()
                                    .onTapGesture {
                                        selectedParticipants.removeAll()
                                        selectedUser = nil
                                    }
                            }
                        }
                        
                        if !selectedParticipants.isEmpty {
                            ForEach(selectedParticipants, id: \.id) { participant in
                                HStack {
                                    Circle()
                                        .fill(Color.pink)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text("\(participant.firstName?.prefix(1) ?? "")\(participant.lastName?.prefix(1) ?? "")")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        )
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(participant.firstName ?? "") \(participant.lastName ?? "")")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("@\(participant.username)")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    Spacer()
                                    Button(action: {
                                        selectedParticipants.removeAll { $0.id == participant.id }
                                        if selectedUser?.id == participant.id {
                                            selectedUser = nil
                                        }
                                    }) {
                                        Image(systemName: "xmark")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical)
                                .cornerRadius(10)
                            }
                        }
                    }
                    
                    // Search Results Section
                    VStack {
                        HStack {
                            Text("KẾT QUẢ TÌM KIẾM")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        if !participantViewModel.searchResults.isEmpty {
                            let existingIds = Set(selectedParticipants.map { $0.id })
                            let participantIds = Set(participantViewModel.participants.map { $0.user_id })
                            
                            List {
                                ForEach(participantViewModel.searchResults, id: \.id) { user in
                                    let isAlreadyAdded = existingIds.contains(user.id)
                                    let isParticipant = participantIds.contains(user.id)
                                    let isSelected = selectedParticipants.contains { $0.id == user.id }
                                    
                                    Button(action: {
                                        if !isAlreadyAdded && !isParticipant {
                                            if isSelected {
                                                selectedParticipants.removeAll { $0.id == user.id }
                                            } else {
                                                selectedParticipants.append(user)
                                            }
                                            selectedUser = nil
                                        }
                                    }) {
                                        HStack {
                                            Circle()
                                                .fill((isAlreadyAdded || isParticipant) ? Color.pink.opacity(0.3) : Color.pink)
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    Text("\(user.firstName?.prefix(1) ?? "")\(user.lastName?.prefix(1) ?? "")")
                                                        .font(.headline)
                                                        .foregroundColor((isAlreadyAdded || isParticipant) ? .gray : .white)
                                                )
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("\(user.firstName ?? "") \(user.lastName ?? "")")
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor((isAlreadyAdded || isParticipant) ? .gray : .white)
                                                Text("@\(user.username)")
                                                    .font(.system(size: 13))
                                                    .foregroundColor((isAlreadyAdded || isParticipant) ? .gray.opacity(0.7) : .white.opacity(0.6))
                                            }
                                            
                                            Spacer()
                                            
                                            if isParticipant {
                                                Text("Thành viên")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            } else if isAlreadyAdded {
                                                Text("Đã thêm")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            } else if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .cornerRadius(12)
                                    }
                                    .disabled(isAlreadyAdded || isParticipant)
                                    .listRowBackground(Color.clear)
                                }
                            }
                            .listStyle(PlainListStyle())
                            .scrollContentBackground(.hidden)
                        } else {
                            VStack {
                                Spacer()
                                Image("detail")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                Text("Không tìm thấy kết quả")
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                    }
                    .padding(.top)
                    
                    Spacer()
                    
                    // Invite Button
                    Button(action: {
                        if selectedParticipants.isEmpty {
                            errorToastMessage = "⚠️ Vui lòng chọn ít nhất một người dùng!"
                            showErrorToast = true
                        } else {
                            participantViewModel.addMultipleParticipants(tripId: trip.id, users: selectedParticipants) { successCount in
                                parentToastMessage = "Đã thêm \(successCount) người dùng"
                                parentShowToast = true
                                selectedParticipants.removeAll()
                                selectedUser = nil
                                searchText = ""
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    dismiss() 
                                }
                            }
                        }
                    }) {
                        Text("Mời vào nhóm")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.Button)
                            .cornerRadius(25)
                    }
                    .disabled(selectedParticipants.isEmpty)
                    .padding()
                }
                .padding(.horizontal)
                
                // Error Toast using SuccessToastView
                if showErrorToast {
                    SuccessToastView(message: errorToastMessage)
                        .offset(y: -50)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showErrorToast = false
                            }
                        }
                }
            }
            .onAppear {
                participantViewModel.fetchParticipants(tripId: trip.id)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private func debounceSearch(query: String) {
        debounceTask?.cancel()
        let task = DispatchWorkItem {
            if !query.isEmpty {
                participantViewModel.searchUsers(query: query)
            } else {
                participantViewModel.searchResults = []
            }
        }
        debounceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }
}
