import Foundation

// Struct cho response JSON
struct TripDayResponse: Codable {
    let success: Bool
    let data: TripDayData?

    struct TripDayData: Codable {
        let tripDays: [TripDay]
    }
}

// Struct cho TripDay
struct TripDay: Codable, Identifiable {
    let id: Int
    let tripId: Int
    let day: String
    let createdAt: String
    let updatedAt: String
    var activities: [TripActivity]

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case day
        case createdAt
        case updatedAt
        case activities
    }
}
struct ErrorResponse: Codable {
    let success: Bool
    let message: String
}
