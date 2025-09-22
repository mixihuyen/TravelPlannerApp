struct User: Codable, Hashable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let username: String?
    let email: String?
    let password: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, username, email, password
        case firstName = "first_name"
        case lastName = "last_name"
        case createdAt, updatedAt
    }
    
    
}
 
struct UserInformation: Codable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let email: String?
    let username: String?
    let createdAt: String?
    let updatedAt: String? 

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case username
        case createdAt
        case updatedAt
    }
}

struct UpdateProfileResponse: Codable {
    let success: Bool
    let statusCode: Int
    let message: String
    let data: UserInformation?
}
