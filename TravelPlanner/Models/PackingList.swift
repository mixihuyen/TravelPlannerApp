import Foundation

struct PackingList: Codable, Equatable {
    var sharedItems: [PackingItem] = []
    var personalItems: [PackingItem] = []
    
    static func == (lhs: PackingList, rhs: PackingList) -> Bool {
            return lhs.sharedItems == rhs.sharedItems &&
                   lhs.personalItems == rhs.personalItems
        }
}
struct CachedPackingList: Codable {
    let timestamp: Date
    let data: [PackingItem]
}
