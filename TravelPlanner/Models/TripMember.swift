import Foundation
struct TripMember: Identifiable {
    let id = UUID()
    var name: String
    var avatar: Data? = nil
    var role: String?
}
