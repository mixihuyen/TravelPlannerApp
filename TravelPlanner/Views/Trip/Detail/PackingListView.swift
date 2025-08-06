import SwiftUI

struct PackingListView: View {
    @State private var selectedTab: TabType = .shared
    @State private var showEditNameAlert = false
    @State private var selectedItem: PackingItem?
    @State private var newItemName = ""
    @State private var showAssignModal = false
    @State private var selectedAssignee: Int?
    @Environment(\.horizontalSizeClass) var size
    @ObservedObject var viewModel: PackingListViewModel
    @State private var hasSavedAssignee: Bool = false
    
    enum TabType: String, CaseIterable {
        case shared = "Chung"
        case personal = "Cá nhân"
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.background
                .ignoresSafeArea()
            
            VStack {
                PackingTabView(selectedTab: $selectedTab)
                    .padding(.top, 60)
                    .padding(.bottom, 20)
                
                HeaderView(
                    onAddTapped: {
                        newItemName = ""
                        showEditNameAlert = true
                        print("➕ Tapped add item button")
                    }
                )
                
                List {
                    ForEach(Array(viewModel.currentItems(for: selectedTab).enumerated()), id: \.1.id) { index, item in
                        ItemRow(
                            item: item,
                            rowIndex: index,
                            isSharedTab: selectedTab == .shared,
                            viewModel: viewModel,
                            selectedTab: selectedTab,
                            onEdit: {
                                selectedItem = item
                                newItemName = item.name
                                showEditNameAlert = true
                            },
                            onAssign: {
                                selectedItem = item
                                selectedAssignee = item.userId
                                showAssignModal = true
                                hasSavedAssignee = false
                            }
                        )
                        .frame(minHeight: 44)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(index % 2 == 0 ? Color.black.opacity(0.05) : Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deletePackingItem(itemId: item.id) {
                                    print("✅ Deleted item: \(item.name) (ID: \(item.id))")
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
            .padding(.horizontal)
            .alert("Thêm vật dụng mới", isPresented: Binding(
                get: { showEditNameAlert && selectedItem == nil },
                set: { if !$0 { showEditNameAlert = false } }
            )) {
                TextField("Tên vật dụng", text: $newItemName)
                Button("Hủy", role: .cancel) {
                    newItemName = ""
                    print("🚫 Canceled creating new item")
                }
                Button("Thêm") {
                    viewModel.createPackingItem(
                        name: newItemName,
                        quantity: 1,
                        isShared: selectedTab == .shared,
                        isPacked: false
                    ) {
                        print("✅ Created new item: \(newItemName)")
                    }
                    newItemName = ""
                }
            } message: {
                Text("Nhập tên vật dụng mới")
            }

            .alert("Chỉnh sửa tên vật dụng", isPresented: Binding(
                get: { showEditNameAlert && selectedItem != nil },
                set: { if !$0 { showEditNameAlert = false } }
            )) {
                TextField("Tên vật dụng", text: $newItemName)
                Button("Hủy", role: .cancel) {
                    selectedItem = nil
                    newItemName = ""
                    print("🚫 Canceled editing item")
                }
                Button("Lưu") {
                    if let item = selectedItem {
                        updateItemName(item: item)
                    }
                    selectedItem = nil
                    newItemName = ""
                }
            } message: {
                Text("Nhập tên mới cho vật dụng")
            }
            .sheet(isPresented: $showAssignModal) {
                AssignModal(
                    viewModel: viewModel,
                    item: selectedItem,
                    selectedUserId: $selectedAssignee,
                    onSave: {
                        if hasSavedAssignee {
                            print("🚫 onSave already called for item: \(selectedItem?.name ?? "unknown"), userId=\(String(describing: selectedAssignee))")
                            return
                        }
                        if let item = selectedItem {
                            hasSavedAssignee = true
                            viewModel.updatePackingItem(
                                itemId: item.id,
                                name: item.name,
                                quantity: item.quantity,
                                isShared: item.isShared,
                                isPacked: item.isPacked,
                                userId: selectedAssignee
                            ) {
                                print("✅ Assigned item \(item.name) to user \(String(describing: selectedAssignee))")
                            }
                        }
                        showAssignModal = false
                    },
                    onCancel: {
                        showAssignModal = false
                        hasSavedAssignee = false
                        print("🚫 Canceled assignment")
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationBackground(.clear)
                .background(Color.background)
                .ignoresSafeArea()
            }
            .overlay(
                Group {
                    if viewModel.showToast, let message = viewModel.toastMessage {
                        SuccessToastView(message: message)
                    }
                },
                alignment: .bottom
            )
        }
        .onAppear {
            viewModel.fetchPackingList()
            print("👥 Participants count: \(viewModel.participants.count)")
        }
    }
    
    private func updateItemName(item: PackingItem) {
        guard !newItemName.isEmpty else {
            print("⚠️ Empty item name")
            return
        }
        viewModel.updatePackingItem(
            itemId: item.id,
            name: newItemName,
            quantity: item.quantity,
            isShared: item.isShared,
            isPacked: item.isPacked,
            userId: item.userId
        ) {
            print("✅ Updated item name: \(newItemName)")
        }
    }
}

private struct HeaderView: View {
    let onAddTapped: () -> Void
    
    var body: some View {
        HStack {
            Text("Danh sách đồ mang theo")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "text.badge.plus")
                .font(.system(size: 25))
                .foregroundColor(.white)
                .onTapGesture(perform: onAddTapped)
        }
        .padding(.bottom, 20)
    }
}
