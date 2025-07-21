struct TripActivity: Codable, Identifiable {
    let id: Int
    let tripDayId: Int
    let startTime: String
    let endTime: String
    let activity: String
    let address: String
    let estimatedCost: String
    let actualCost: String
    let note: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case tripDayId = "trip_day_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case activity
        case address
        case estimatedCost = "estimated_cost"
        case actualCost = "actual_cost"
        case note
        case createdAt
        case updatedAt
    }
}

