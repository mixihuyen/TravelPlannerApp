import Foundation

struct PackingItem: Identifiable {
    let id = UUID()
    var name: String
    var isShared: Bool // true = đồ dùng chung, false = cá nhân
    var isPacked: Bool // đã đánh dấu là đã chuẩn bị xong chưa
    var ownerId: UUID? // nếu là đồ cá nhân, gán member.id
}
