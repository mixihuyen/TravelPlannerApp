// MARK: - API Response Models
struct TripDashboardResponse: Codable {
    let success: Bool
    let data: TripDashboardData
}

struct TripDashboardData: Codable {
    let totalExpected: Double
    let totalActual: Double
    let balance: Double
    let activityCosts: [TripActivity]

    enum CodingKeys: String, CodingKey {
        case totalExpected = "total_expected"
        case totalActual = "total_actual"
        case balance
        case activityCosts = "activityCosts"
    }
}

// MARK: - Dashboard Model (Thay thế TripModel)
struct TripDashboardModel: Codable, Identifiable {
    let id: Int // tripId để xác định chuyến đi
    let activities: [TripActivity]
    let totalEstimated: Double
    let totalActual: Double
    let balance: Double
}
