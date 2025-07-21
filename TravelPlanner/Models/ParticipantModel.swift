import Foundation

struct Participant: Codable, Identifiable {
    let id: Int
    let trip_id: Int
    let user_id: Int
    let role: String
    let joined_at: String
    let createdAt: String
    let updatedAt: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case id, trip_id, user_id, role, joined_at, createdAt, updatedAt
        case user = "User" 
    }
}

struct ParticipantResponse: Codable {
    let success: Bool
    let message: String?
    let data: ParticipantDataResponse?
}

struct ParticipantDataResponse: Codable {
    let participants: [Participant]
}
