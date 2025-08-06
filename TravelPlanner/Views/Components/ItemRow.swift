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
                print("✅ User toggled item \(item.name) to isPacked=\(newValue)")
            }

            Spacer()

            if isSharedTab {
                Circle()
                    .fill(item.userId != nil ? Color.pink : Color.gray.opacity(0.5))
                    .frame(width: 43, height: 43)
                    .overlay(
                        Group {
                            if item.userId != nil {
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
                    .onTapGesture(perform: onAssign)
            }

        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(rowIndex % 2 == 0 ? Color("dark") : Color("light"))
        .onTapGesture {
                    onEdit()
                }
    }
}
