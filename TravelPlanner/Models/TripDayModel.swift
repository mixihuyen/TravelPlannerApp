import Foundation
import CoreData

// Struct cho response JSON
struct TripDayResponse: Codable {
    let success: Bool
    let data: TripDayData?

    struct TripDayData: Codable {
        let tripDays: [TripDay]
    }
}

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

    init(from entity: TripDayEntity) {
        self.id = Int(entity.id)
        self.tripId = Int(entity.tripId)
        self.day = entity.day ?? ""
        self.createdAt = entity.createdAt ?? ""
        self.updatedAt = entity.updatedAt ?? ""
        if let activitiesData = entity.activitiesData as? Data {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                self.activities = try decoder.decode([TripActivity].self, from: activitiesData)
            } catch {
                print("Lỗi decode activities: \(error)")
                self.activities = []
            }
        } else {
            self.activities = []
        }
    }

    func toEntity(context: NSManagedObjectContext) -> TripDayEntity {
        let entity = TripDayEntity(context: context)
        entity.id = Int32(id)
        entity.tripId = Int32(tripId)
        entity.day = day
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(activities)
            entity.activitiesData = data as NSObject
        } catch {
            print("Lỗi encode activities: \(error)")
            entity.activitiesData = nil
        }
        return entity
    }
}

struct ErrorResponse: Codable {
    let success: Bool
    let message: String
}
