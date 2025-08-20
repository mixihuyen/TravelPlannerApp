struct TripParticipant: Codable, Hashable, Identifiable {
    let id: Int
    let tripId: Int
    let userId: Int
    let role: String
    let joinedAt: String
    let createdAt: String
    let updatedAt: String 
    let user: User?

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case createdAt, updatedAt
        case user = "User"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TripParticipant, rhs: TripParticipant) -> Bool {
        lhs.id == rhs.id
    }
}
