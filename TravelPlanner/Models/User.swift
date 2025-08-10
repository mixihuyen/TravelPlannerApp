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
