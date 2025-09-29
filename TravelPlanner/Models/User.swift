
struct UserInformation: Codable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let email: String?
    let username: String?
    let createdAt: String?
    let updatedAt: String?
    let avatar: AvatarData?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case username
        case createdAt
        case updatedAt
        case avatar
    }
}

struct UpdateProfileResponse: Codable {
    let success: Bool
    let statusCode: Int
    let message: String
    let data: UserInformation?
}
struct AvatarData: Codable {
    let id: Int
    let imagetableId: Int?
    let imagetableType: String?
    let url: String
    let publicId: String
    let altText: String?
    let status: String
    let createdByUserId: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case imagetableId
        case imagetableType
        case url
        case publicId = "public_id"
        case altText = "alt_text"
        case status
        case createdByUserId = "created_by_user_id"
        case createdAt
        case updatedAt
    }
    
}

// MARK: - Supporting Models
struct UpdateProfileRequest: Codable {
    let firstName: String
    let lastName: String
    let username: String
    let avatarId: Int?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case username
        case avatarId = "avatar"
    }
}
