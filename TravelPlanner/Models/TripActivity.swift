import Foundation
import CoreData
import DGCharts

struct TripActivity: Codable, Identifiable, Hashable {
    let id: Int
    let tripDayId: Int
    let startTime: String
    let endTime: String
    let activity: String
    let address: String
    let estimatedCost: Double
    let actualCost: Double?
    let note: String
    let createdAt: String
    let updatedAt: String
    let activityImages: [ImageData]?

    init(
        id: Int,
        tripDayId: Int,
        startTime: String,
        endTime: String,
        activity: String,
        address: String,
        estimatedCost: Double,
        actualCost: Double?,
        note: String,
        createdAt: String,
        updatedAt: String,
        activityImages: [ImageData]?
    ) {
        self.id = id
        self.tripDayId = tripDayId
        self.startTime = startTime
        self.endTime = endTime
        self.activity = activity
        self.address = address
        self.estimatedCost = estimatedCost
        self.actualCost = actualCost
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.activityImages = activityImages
    }

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
        case activityImages = "activity_images"
    }

    static func ==(lhs: TripActivity, rhs: TripActivity) -> Bool {
            return lhs.id == rhs.id &&
                   lhs.tripDayId == rhs.tripDayId &&
                   lhs.startTime == rhs.startTime &&
                   lhs.endTime == rhs.endTime &&
                   lhs.activity == rhs.activity &&
                   lhs.address == rhs.address &&
                   lhs.estimatedCost == rhs.estimatedCost &&
                   lhs.actualCost == rhs.actualCost &&
                   lhs.note == rhs.note &&
                   lhs.createdAt == rhs.createdAt &&
                   lhs.updatedAt == rhs.updatedAt 
        }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func toEntity(context: NSManagedObjectContext) -> ActivityEntity {
        let entity = ActivityEntity(context: context)
        entity.id = Int64(id)
        entity.tripDayId = Int64(tripDayId)
        entity.startTime = startTime
        entity.endTime = endTime
        entity.activity = activity
        entity.address = address
        entity.estimatedCost = estimatedCost
        entity.actualCost = actualCost ?? 0
        entity.note = note
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        return entity
    }

    init(from entity: ActivityEntity) {
        self.id = Int(entity.id)
        self.tripDayId = Int(entity.tripDayId)
        self.startTime = entity.startTime ?? ""
        self.endTime = entity.endTime ?? ""
        self.activity = entity.activity ?? ""
        self.address = entity.address ?? ""
        self.estimatedCost = entity.estimatedCost
        self.actualCost = entity.actualCost != 0 ? entity.actualCost : nil
        self.note = entity.note ?? ""
        self.createdAt = entity.createdAt ?? ""
        self.updatedAt = entity.updatedAt ?? ""
        self.activityImages = []
    }
}

extension TripActivity {
    func toPieEntry() -> PieChartDataEntry? {
        guard let actualCostValue = actualCost, actualCostValue > 0 else { return nil }
        return PieChartDataEntry(value: actualCostValue, label: activity)
    }
}

struct TripActivityResponse: Codable {
    let success: Bool
    let message: String?
    let statusCode: Int
    let reasonStatusCode: String
    let data: TripActivity?
}

struct TripActivityUpdateResponse: Codable {
    let success: Bool
    let message: String?
    let statusCode: Int
    let reasonStatusCode: String
    let data: TripActivity?
}

struct DeleteActivityResponse: Codable {
    let success: Bool
    let message: String?
}

struct TripActivityListResponse: Codable {
    let success: Bool
    let message: String?
    let statusCode: Int
    let reasonStatusCode: String
    let data: [TripActivity]?
}
