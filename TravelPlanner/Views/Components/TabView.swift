import SwiftUI
struct PackingTabView: View {
    @Binding var selectedTab: PackingListView.TabType

    var body: some View {
        HStack {
            ForEach(PackingListView.TabType.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                    print("🔄 Switched to tab: \(tab.rawValue)")
                } label: {
                    Text(tab.rawValue)
                        .fontWeight(selectedTab == tab ? .bold : .regular)
                        .foregroundColor(.white)
                        .underline(selectedTab == tab, color: .white)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
