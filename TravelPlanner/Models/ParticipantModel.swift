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
    let data: ParticipantData?
    
    
    struct ParticipantData: Codable {
        let participants: [Participant]
    }
}
struct UserSearchResponse: Codable {
    let success: Bool
    let message: String?
    let data: [User]?
}

struct AddParticipantResponse: Codable {
    let success: Bool
    let message: String?
    let data: AddParticipantData?
}

struct AddParticipantData: Codable {
    let tripParticipant: TripParticipant
}
struct BaseResponse: Decodable {
    let success: Bool
    let message: String?
}

