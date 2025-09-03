import Foundation

struct ActivityImage: Codable, Identifiable {
    let id: Int
    let tripActivityId: Int
    let imageUrl: String?
    let uploadedAt: String
    let userId: Int?
    let createdAt: String
    let updatedAt: String
    let userInformation: User?

    enum CodingKeys: String, CodingKey {
        case id
        case tripActivityId = "trip_activity_id"
        case imageUrl = "image_url"
        case uploadedAt = "uploaded_at"
        case userId = "user_id"
        case createdAt
        case updatedAt
        case userInformation = "user_information"
    }
}
// Model cho phản hồi GET (lấy danh sách ảnh)
struct ActivityImagesFetchResponse: Codable {
    let success: Bool
    let data: [ActivityImage]
}

// Model cho phản hồi POST (tạo ảnh mới)
struct ActivityImageCreateResponse: Codable {
    let success: Bool
    let data: ActivityImage
}
