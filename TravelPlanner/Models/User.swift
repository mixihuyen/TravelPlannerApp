import Foundation
struct User: Codable {
    let id: Int
    let email: String
    var first_name: String?
    var last_name: String?
    var username: String?
}
