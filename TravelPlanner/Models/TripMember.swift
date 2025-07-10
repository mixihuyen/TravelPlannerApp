import Foundation
struct TripMember: Identifiable, Codable {
    let id: String
    var name: String
    var avatar: Data?
    var role: MemberRole?

    init(id: String = UUID().uuidString, name: String, avatar: Data? = nil, role: MemberRole? = nil) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.role = role
    }

    enum MemberRole: String, Codable {
        case planner = "Người lên kế hoạch"
        case treasurer = "Thu quỹ"
        case member = "Thành viên"
    }
}
