import Foundation
import CoreData

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
    init(
        id: Int,
        name: String,
        description: String?,
        startDate: String,
        endDate: String,
        address: String?,
        imageCoverUrl: String?,
        isPublic: Bool,
        status: String,
        createdByUserId: Int,
        createdAt: String,
        updatedAt: String,
        tripParticipants: [TripParticipant]?
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.address = address
        self.imageCoverUrl = imageCoverUrl
        self.isPublic = isPublic
        self.status = status
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tripParticipants = tripParticipants
    }
    
    
    static func == (lhs: TripModel, rhs: TripModel) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    init(from entity: TripEntity) {
        self.id = Int(entity.id)
        self.name = entity.name ?? ""
        self.description = entity.des ?? ""
        self.startDate = entity.startDate ?? ""
        self.endDate = entity.endDate ?? ""
        self.address = entity.address ?? ""
        self.imageCoverUrl = entity.imageCoverUrl ?? ""
        self.isPublic = entity.isPublic
        self.status = entity.status ?? "planned"
        self.createdByUserId = Int(entity.createdByUserId)
        self.createdAt = entity.createdAt ?? ""
        self.updatedAt = entity.updatedAt ?? ""
        if let participantsData = entity.tripParticipants as? Data {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601 // Xử lý ngày giờ
                let participants = try decoder.decode([TripParticipant].self, from: participantsData)
                self.tripParticipants = participants
            } catch {
                print("Lỗi decode tripParticipants: \(error)")
                self.tripParticipants = []
            }
        } else {
            self.tripParticipants = []
        }
    }
    
    func toEntity(context: NSManagedObjectContext) -> TripEntity {
        let entity = TripEntity(context: context)
        entity.id = Int32(id)
        entity.name = name
        entity.des = description 
        entity.startDate = startDate
        entity.endDate = endDate
        entity.address = address
        entity.imageCoverUrl = imageCoverUrl
        entity.isPublic = isPublic
        entity.status = status
        entity.createdByUserId = Int32(createdByUserId)
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(tripParticipants ?? [])
            entity.tripParticipants = data as NSObject
        } catch {
            print("Lỗi encode tripParticipants: \(error)")
            entity.tripParticipants = nil
        }
        return entity
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
