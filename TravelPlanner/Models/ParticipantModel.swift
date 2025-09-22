import Foundation

struct Participant: Codable, Identifiable {
    let id: Int
    let tripId: Int
    let userId: Int
    var role: String
    let joinedAt: String
    let createdAt: String
    var updatedAt: String
    let userInformation: UserInformation

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case createdAt
        case updatedAt
        case userInformation = "user_information"
    }
}

struct ParticipantsResponse: Codable {
    let success: Bool
    let message: String?
    let statusCode: Int
    let reasonStatusCode: String
    let data: [Participant]?
}
struct UserSearchResponse: Codable {
    let success: Bool
    let message: String?
    let data: [UserInformation]?
}

struct ParticipantResponse: Codable {
    let success: Bool
    let message: String?
    let statusCode: Int
    let reasonStatusCode: String
    let data: TripParticipant?
}
struct BaseResponse: Decodable {
    let success: Bool
    let message: String?
}

