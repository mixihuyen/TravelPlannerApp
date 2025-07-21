import Foundation

struct TripModel: Identifiable, Codable, Hashable{
    let id: Int
    let name: String
    let description: String?
    let startDate: String
    let endDate: String
    let status: String
    let createdByUserId: Int
    let createdAt: String
    let updatedAt: String
    let tripParticipants: [TripParticipant]?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case startDate = "start_date"
        case endDate = "end_date"
        case status
        case createdByUserId = "created_by_user_id"
        case createdAt, updatedAt
        case tripParticipants = "TripParticipants"
    }
}

struct TripSingleResponse: Codable {
    let success: Bool
    let data: TripModel
}


struct TripListResponse: Codable {
    let success: Bool
    let data: [TripModel]
}

