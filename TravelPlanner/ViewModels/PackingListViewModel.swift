//import Foundation
//import Combine
//import SwiftUI
//
//class PackingListViewModel: ObservableObject {
//    @Published var packingList: PackingList
//    @Published var participants: [Participant] = []
//    private var cancellables = Set<AnyCancellable>()
//
//    // Dữ liệu dummy cho packing list
//    static let samplePackingList = PackingList(
//        sharedItems: [
//            PackingItem(name: "Lều cắm trại", isChecked: false, assignedTo: nil),
//            PackingItem(name: "Bếp dã ngoại", isChecked: true, assignedTo: "mixihuyen"),
//            PackingItem(name: "Đèn pin", isChecked: false, assignedTo: nil)
//        ],
//        personalItems: [
//            PackingItem(name: "Áo mưa", isChecked: false, assignedTo: "mixihuyen"),
//            PackingItem(name: "Giày leo núi", isChecked: true, assignedTo: "trungcry"),
//            PackingItem(name: "Ba lô", isChecked: false, assignedTo: nil)
//        ]
//    )
//
//    init(tripId: Int) {
//        self.packingList = Self.samplePackingList
//        fetchParticipants(tripId: tripId)
//    }
//
//    func fetchParticipants(tripId: Int) {
//        guard let url = URL(string: "https://travel-api-79ct.onrender.com/api/v1/trips/\(tripId)/participants") else {
//            print("URL không hợp lệ")
//            return
//        }
//
//        URLSession.shared.dataTaskPublisher(for: url)
//            .map { $0.data }
//            .decode(type: ParticipantResponse.self, decoder: JSONDecoder())
//            .receive(on: DispatchQueue.main)
//            .sink { completion in
//                switch completion {
//                case .failure(let error):
//                    print("Lỗi khi fetch participants: \(error)")
//                case .finished:
//                    print("Fetch participants thành công")
//                }
//            } receiveValue: { [weak self] response in
//                guard let self = self else { return }
//                self.participants = response.data.participants
//            }
//            .store(in: &cancellables)
//    }
//
//    func currentItems(for tab: PackingListView.TabType) -> [PackingItem] {
//        switch tab {
//        case .shared:
//            return packingList.sharedItems
//        case .personal:
//            return packingList.personalItems
//        }
//    }
//
//    func binding(for item: PackingItem, in tab: PackingListView.TabType) -> Binding<Bool> {
//        switch tab {
//        case .shared:
//            guard let index = packingList.sharedItems.firstIndex(where: { $0.id == item.id }) else {
//                return .constant(false)
//            }
//            return Binding(
//                get: { self.packingList.sharedItems[index].isChecked },
//                set: { self.packingList.sharedItems[index].isChecked = $0 }
//            )
//
//        case .personal:
//            guard let index = packingList.personalItems.firstIndex(where: { $0.id == item.id }) else {
//                return .constant(false)
//            }
//            return Binding(
//                get: { self.packingList.personalItems[index].isChecked },
//                set: { self.packingList.personalItems[index].isChecked = $0 }
//            )
//        }
//    }
//
//    func ownerInitials(for item: PackingItem) -> String {
//        guard let username = item.assignedTo,
//              let participant = participants.first(where: { $0.user.username == username }) else {
//            return ""
//        }
//
//        let firstInitial = participant.user.firstName?.prefix(1) ?? ""
//        let lastInitial = participant.user.lastName?.prefix(1) ?? ""
//        return "\(firstInitial)\(lastInitial)"
//    }
//
//    // Hàm để cập nhật trạng thái isChecked của một item
//    func toggleItemChecked(itemId: String) {
//        if let index = packingList.sharedItems.firstIndex(where: { $0.id == itemId }) {
//            packingList.sharedItems[index].isChecked.toggle()
//        } else if let index = packingList.personalItems.firstIndex(where: { $0.id == itemId }) {
//            packingList.personalItems[index].isChecked.toggle()
//        }
//    }
//
//    // Hàm để gán item cho một participant
//    func assignItem(itemId: String, to username: String?) {
//        if let index = packingList.sharedItems.firstIndex(where: { $0.id == itemId }) {
//            packingList.sharedItems[index].assignedTo = username
//        } else if let index = packingList.personalItems.firstIndex(where: { $0.id == itemId }) {
//            packingList.personalItems[index].assignedTo = username
//        }
//    }
//}
