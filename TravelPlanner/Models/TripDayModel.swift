import Foundation
import CoreData

// Struct cho response JSON
struct TripDayResponse: Codable {
    let success: Bool
    let message: String
    let statusCode: Int
    let reasonStatusCode: String
    let data: [TripDay]
}

struct TripDay: Codable, Identifiable {
    let id: Int
    let tripId: Int
    let day: String
    let createdAt: String
    let updatedAt: String
    var activities: [TripActivity]?

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case day
        case createdAt
        case updatedAt
        case activities
    }

    init(from entity: TripDayEntity) {
        self.id = Int(entity.id)
        self.tripId = Int(entity.tripId)
        self.day = entity.day ?? ""
        self.createdAt = entity.createdAt ?? ""
        self.updatedAt = entity.updatedAt ?? ""
        self.activities = (try? JSONDecoder().decode([TripActivity].self, from: entity.activitiesData ?? Data())) ?? []
    }

    func toEntity(context: NSManagedObjectContext) -> TripDayEntity {
        let entity = TripDayEntity(context: context)
        entity.id = Int32(id)
        entity.tripId = Int32(tripId)
        entity.day = day
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        if let activities = activities, let data = try? JSONEncoder().encode(activities) {
                entity.activitiesData = data
            }
            return entity
    }
}
struct SingleTripDayResponse: Codable {
    let success: Bool
    let message: String
    let statusCode: Int
    let reasonStatusCode: String
    let data: TripDay
}


