//import SwiftUI
//
//struct PackingListView: View {
//    @State private var selectedTab: TabType = .shared
//    @Environment(\.horizontalSizeClass) var size
//    
//    @ObservedObject var viewModel: PackingListViewModel
//    
//    enum TabType: String, CaseIterable {
//        case shared = "Chung"
//        case personal = "Cá nhân"
//    }
//    
//    var columns: [GridItem] {
//        size == .compact
//        ? [GridItem(.flexible())]
//        : [GridItem(.flexible()), GridItem(.flexible())]
//    }
//    
//    var body: some View {
//        ZStack(alignment: .topLeading) {
//            Color.background.ignoresSafeArea()
//            
//            VStack {
//                // Tab switcher
//                HStack {
//                    ForEach(TabType.allCases, id: \.self) { tab in
//                        Button {
//                            selectedTab = tab
//                        } label: {
//                            Text(tab.rawValue)
//                                .fontWeight(selectedTab == tab ? .bold : .regular)
//                                .foregroundColor(.white)
//                                .underline(selectedTab == tab, color: .white)
//                                .frame(maxWidth: .infinity)
//                        }
//                    }
//                }
//                .padding(.top, 60)
//                .padding(.bottom, 20)
//                
//                // Title
//                HStack {
//                    Text("Danh sách đồ mang theo")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                    Spacer()
//                    Image(systemName: "text.badge.plus")
//                        .font(.system(size: 25))
//                        .foregroundColor(.white)
//                }
//                
//                // List
//                ScrollView {
//                    VStack(spacing: 0) {
//                        LazyVGrid(columns: columns, spacing: 0) {
//                            ForEach(Array(viewModel.currentItems(for: selectedTab).enumerated()), id: \.1.id) { index, item in
//                                let rowIndex = index / columns.count
//                                HStack {
//                                    Toggle(isOn: viewModel.binding(for: item, in: selectedTab)) {
//                                        Text(item.name)
//                                            .foregroundColor(.white)
//                                    }
//                                    .toggleStyle(CheckToggleStyle())
//                                    
//                                    Spacer()
//                                    
//                                    if selectedTab == .shared {
//                                        Circle()
//                                            .fill(Color.pink)
//                                            .frame(width: 28, height: 28)
//                                            .overlay(
//                                                Text(viewModel.ownerInitials(for: item))
//                                                    .font(.caption)
//                                                    .foregroundColor(.white)
//                                            )
//                                    }
//                                }
//                                .padding(.horizontal)
//                                .padding(.vertical, 12)
//                                .background(rowIndex % 2 == 0 ? Color("dark") : Color("light"))
//                            }
//                        }
//                    }
//                }
//            }
//            .padding(.horizontal)
//        }
//    }
//}
