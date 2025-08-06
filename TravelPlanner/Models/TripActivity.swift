import Foundation
import DGCharts

struct TripActivity: Codable, Identifiable, Hashable {
    let id: Int
    let tripDayId: Int
    let startTime: String
    let endTime: String
    let activity: String
    let address: String
    let estimatedCost: Double
    let actualCost: Double
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

    // Triển khai Hashable
    static func == (lhs: TripActivity, rhs: TripActivity) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension TripActivity {
    func toPieEntry() -> PieChartDataEntry? {
        guard actualCost > 0 else { return nil } 
        return PieChartDataEntry(value: actualCost, label: activity)
    }
}

struct TripActivityResponse: Codable {
    let success: Bool
    let data: TripActivity?
}

struct TripActivityUpdateResponse: Codable {
    let success: Bool
    let data: UpdatedActivityWrapper?

    struct UpdatedActivityWrapper: Codable {
        let updatedActivity: TripActivity

        enum CodingKeys: String, CodingKey {
            case updatedActivity
        }
    }
}
struct DeleteActivityResponse: Codable {
    let success: Bool
    let message: String?
}
