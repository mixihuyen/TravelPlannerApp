import Foundation

struct PackingList: Codable {
    var sharedItems: [PackingItem] = []
    var personalItems: [PackingItem] = []
}
