import Foundation

struct TripModel: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let startDate: String
    let endDate: String
    let address: String?
    let imageCoverUrl: String?
    let isPublic: Bool
    let status: String
    let createdByUserId: Int
    let createdAt: String
    let updatedAt: String
    var tripParticipants: [TripParticipant]?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case startDate = "start_date"
        case endDate = "end_date"
        case address
        case imageCoverUrl = "image_cover_url"
        case isPublic = "public"
        case status
        case createdByUserId = "created_by_user_id"
        case createdAt, updatedAt
        case tripParticipants = "TripParticipants"
    }

    static func == (lhs: TripModel, rhs: TripModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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

struct VoidResponse: Codable {}

struct TripRequest: Codable {
    let name: String
    let description: String?
    let startDate: String
    let endDate: String
    let address: String?
    let imageCoverUrl: String?
    let isPublic: Bool
    let status: String
    let createdByUserId: Int

    enum CodingKeys: String, CodingKey {
        case name, description, status
        case startDate = "start_date"
        case endDate = "end_date"
        case address
        case imageCoverUrl = "image_cover_url"
        case isPublic = "public"
        case createdByUserId = "created_by_user_id"
    }
}


