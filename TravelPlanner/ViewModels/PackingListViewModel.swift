import Foundation
import SwiftUI

class PackingListViewModel: ObservableObject {
    @Published var packingList: PackingList
    let members: [TripMember]

    init(packingList: PackingList, members: [TripMember]) {
        self.packingList = packingList
        self.members = members
    }

    func currentItems(for tab: PackingListView.TabType) -> [PackingItem] {
        switch tab {
        case .shared:
            return packingList.sharedItems
        case .personal:
            return packingList.personalItems
        }
    }

    func binding(for item: PackingItem, in tab: PackingListView.TabType) -> Binding<Bool> {
        switch tab {
        case .shared:
            guard let index = packingList.sharedItems.firstIndex(where: { $0.id == item.id }) else {
                return .constant(false)
            }
            return Binding(
                get: { self.packingList.sharedItems[index].isChecked },
                set: { self.packingList.sharedItems[index].isChecked = $0 }
            )

        case .personal:
            guard let index = packingList.personalItems.firstIndex(where: { $0.id == item.id }) else {
                return .constant(false)
            }
            return Binding(
                get: { self.packingList.personalItems[index].isChecked },
                set: { self.packingList.personalItems[index].isChecked = $0 }
            )
        }
    }

    func ownerInitials(for item: PackingItem) -> String {
        guard let id = item.assignedTo,
              let member = members.first(where: { $0.id == id }) else {
            return ""
        }

        let parts = member.name.split(separator: " ")
        return parts.compactMap { $0.first }.map(String.init).joined()
    }
}
