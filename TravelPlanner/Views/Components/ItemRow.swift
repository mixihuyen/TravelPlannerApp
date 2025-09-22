import SwiftUI

struct ItemRow: View {
    let item: PackingItem
    let rowIndex: Int
    let isSharedTab: Bool
    let viewModel: PackingListViewModel
    let selectedTab: PackingListView.TabType
    let onEdit: () -> Void
    let onAssign: () -> Void

    var body: some View {
        HStack {
            Toggle(isOn: viewModel.binding(for: item, in: selectedTab)) {
                Text(item.name)
            }
            .toggleStyle(CheckToggleStyle())
            .labelsHidden()
            .onChange(of: viewModel.binding(for: item, in: selectedTab).wrappedValue) { newValue in
                print("✅ User toggled item \(item.name) (ID: \(item.id)) to isPacked=\(newValue)")
            }

            Spacer()

            if isSharedTab {
                Circle()
                    .fill(item.assignedToUserId != nil ? Color.pink : Color.gray.opacity(0.5)) // Sửa: Sử dụng assignedToUserId
                    .frame(width: 43, height: 43)
                    .overlay(
                        Group {
                            if item.assignedToUserId != nil { // Sửa: Sử dụng assignedToUserId
                                Text(viewModel.ownerInitials(for: item))
                                    .font(.headline)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 22, weight: .bold))
                            }
                        }
                    )
                    .onTapGesture {
                        if viewModel.isOffline {
                            viewModel.showToast(message: "Không thể phân công trong tab Chung khi offline", type: .error)
                            print("⚠️ Blocked assign action in shared tab while offline")
                            return
                        }
                        generateHapticFeedback()
                        onAssign()
                    }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(rowIndex % 2 == 0 ? Color.black.opacity(0.05) : Color.clear) // Đồng bộ với PackingListView
        .onTapGesture {
            if isSharedTab && viewModel.isOffline {
                viewModel.showToast(message: "Không thể chỉnh sửa vật dụng trong tab Chung khi offline", type: .error)
                print("⚠️ Blocked edit action in shared tab while offline")
                return
            }
            generateHapticFeedback()
            onEdit()
        }
    }

    // Hàm tạo phản hồi haptic
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}
