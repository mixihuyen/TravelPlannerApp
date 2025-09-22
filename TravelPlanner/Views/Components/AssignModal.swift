import SwiftUI
import Combine

struct AssignModal: View {
    @ObservedObject var viewModel: PackingListViewModel
    let item: PackingItem?
    @Binding var selectedUserId: Int?
    let onSave: () -> Void
    let onCancel: () -> Void
    @State private var hasSaved: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: {
                        onCancel()
                        hasSaved = false
                        print("🚫 Canceled assignment for item: \(item?.name ?? "unknown")")
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.black)
                            .padding(12)
                    }
                }

                ScrollView {
                    VStack(spacing: 10) {
                        assignOption(
                            title: "Chưa được phân công",
                            subtitle: nil,
                            initials: nil,
                            userId: nil
                        )

                        ForEach(viewModel.participants, id: \.userInformation.id) { participant in
                            let initials = viewModel.initials(for: participant.userInformation)
                            assignOption(
                                title: "\(participant.userInformation.firstName ?? "") \(participant.userInformation.lastName ?? "")",
                                subtitle:"@\(participant.userInformation.username ?? "Unknown" ) ",
                                initials: initials,
                                userId: participant.userInformation.id
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 0)
            }
            .onAppear {
                selectedUserId = item?.assignedToUserId
                hasSaved = false
                print("👤 AssignModal appeared for item: \(item?.name ?? "unknown"), current userId=\(String(describing: selectedUserId))")
            }
        }
    }

    @ViewBuilder
        private func assignOption(title: String, subtitle: String?, initials: String?, userId: Int?) -> some View {
            let isSelected = userId == selectedUserId

            Button {
                print("🖱️ Button tapped for userId=\(String(describing: userId)), item: \(item?.name ?? "unknown")")
                if userId == selectedUserId || hasSaved {
                    print("🚫 No change for item: \(item?.name ?? "unknown"), userId=\(String(describing: userId)) already selected or saved")
                    onCancel()
                } else {
                    selectedUserId = userId
                    hasSaved = true
                    print("👤 Selected userId=\(String(describing: userId)) for item: \(item?.name ?? "unknown")")
                    onSave()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.pink : Color.gray.opacity(0.5))
                            .frame(width: 40, height: 40)

                        if let initials = initials {
                            Text(initials)
                                .foregroundColor(.white)
                                .font(.subheadline.bold())
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .bold))
                        }
                    }

                    VStack(alignment: .leading) {
                        Text(title)
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .bold))

                        if let subtitle = subtitle {
                            Text(subtitle)
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.pink)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(isSelected ? Color.pink.opacity(0.1) : Color.clear)
                .cornerRadius(10)
            }
            .disabled(hasSaved)
        }
    }
