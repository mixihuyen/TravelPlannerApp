import Foundation
import CoreData

struct TripModel: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let startDate: String
    let endDate: String
    let address: String?
    let isPublic: Bool
    let status: String
    let createdByUserId: Int
    let coverImage: Int? // ID của ảnh
    var coverImageInfo: ImageData?  // Thông tin chi tiết của ảnh
    let createdAt: String
    let updatedAt: String
    var imageCoverData: Data? // Dữ liệu ảnh cục bộ (giữ nguyên để lưu cache)
    var tripParticipants: [TripParticipant]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, address, status, createdAt, updatedAt
        case startDate = "start_date"
        case endDate = "end_date"
        case isPublic = "is_public"
        case createdByUserId = "created_by_user_id"
        case coverImage = "cover_image"
        case coverImageInfo = "cover_image_info"
        case tripParticipants = "TripParticipants"
    }
    
    init(
        id: Int,
        name: String,
        description: String?,
        startDate: String,
        endDate: String,
        address: String?,
        coverImage: Int?,
        coverImageInfo: ImageData?,
        imageCoverData: Data?,
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
        self.coverImage = coverImage
        self.coverImageInfo = coverImageInfo
        self.imageCoverData = imageCoverData
        self.isPublic = isPublic
        self.status = status
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tripParticipants = tripParticipants
    }
    
    static func == (lhs: TripModel, rhs: TripModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.description == rhs.description &&
               lhs.startDate == rhs.startDate &&
               lhs.endDate == rhs.endDate &&
               lhs.address == rhs.address &&
               lhs.coverImage == rhs.coverImage &&
               lhs.coverImageInfo == rhs.coverImageInfo &&
               lhs.imageCoverData == rhs.imageCoverData &&
               lhs.isPublic == rhs.isPublic &&
               lhs.status == rhs.status &&
               lhs.createdByUserId == rhs.createdByUserId &&
               lhs.createdAt == rhs.createdAt &&
               lhs.updatedAt == rhs.updatedAt &&
               lhs.tripParticipants == rhs.tripParticipants
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(startDate)
        hasher.combine(endDate)
        hasher.combine(address)
        hasher.combine(coverImage)
        hasher.combine(coverImageInfo)
        hasher.combine(imageCoverData)
        hasher.combine(isPublic)
        hasher.combine(status)
        hasher.combine(createdByUserId)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
        hasher.combine(tripParticipants)
    }
    
    func toEntity(context: NSManagedObjectContext) -> TripEntity {
        let entity = TripEntity(context: context)
        entity.id = Int32(id)
        entity.name = name
        entity.des = description
        entity.startDate = startDate
        entity.endDate = endDate
        entity.address = address
        entity.coverImage = coverImage != nil ? Int32(coverImage!) : 0
        if let coverImageInfo = coverImageInfo {
            if let jsonData = try? JSONEncoder().encode(coverImageInfo) {
                entity.coverImageInfo = jsonData
            }
        }
        entity.imageCoverData = imageCoverData
        entity.isPublic = isPublic
        entity.status = status
        entity.createdByUserId = Int32(createdByUserId)
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        
        if let participants = tripParticipants, !participants.isEmpty {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(participants)
                entity.tripParticipants = data as NSObject
                print("💾 Encoded \(participants.count) participants for tripId=\(id): \(participants.map { "\($0.userId):\($0.role)" })")
            } catch {
                print("❌ Lỗi encode tripParticipants cho tripId=\(id): \(error)")
                entity.tripParticipants = nil
            }
        } else {
            print("⚠️ No participants to encode for tripId=\(id)")
            entity.tripParticipants = nil
        }
        return entity
    }
    
    init(from entity: TripEntity) {
        self.id = Int(entity.id)
        self.name = entity.name ?? ""
        self.description = entity.des
        self.startDate = entity.startDate ?? ""
        self.endDate = entity.endDate ?? ""
        self.address = entity.address
        self.coverImage = entity.coverImage != 0 ? Int(entity.coverImage) : nil
        if let coverImageInfoData = entity.coverImageInfo,
           let coverImageInfo = try? JSONDecoder().decode(ImageData.self, from: coverImageInfoData) {
            self.coverImageInfo = coverImageInfo
        } else {
            self.coverImageInfo = nil
        }
        self.imageCoverData = entity.imageCoverData
        self.isPublic = entity.isPublic
        self.status = entity.status ?? "planned"
        self.createdByUserId = Int(entity.createdByUserId)
        self.createdAt = entity.createdAt ?? ""
        self.updatedAt = entity.updatedAt ?? ""
        
        if let participantsData = entity.tripParticipants as? Data, !participantsData.isEmpty {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let participants = try decoder.decode([TripParticipant].self, from: participantsData)
                self.tripParticipants = participants
                print("📂 Decoded \(participants.count) participants for tripId=\(id): \(participants.map { "\($0.userId):\($0.role)" })")
            } catch {
                print("❌ Lỗi decode tripParticipants cho tripId=\(id): \(error)")
                self.tripParticipants = []
            }
        } else {
            print("⚠️ No participants data in cache for tripId=\(id)")
            self.tripParticipants = []
        }
    }
}

struct TripSingleResponse: Codable {
    let success: Bool
    let message: String
    let statusCode: Int
    let reasonStatusCode: String
    let data: TripModel
}

struct TripListResponse: Codable {
    let success: Bool
    let message: String
    let statusCode: Int
    let reasonStatusCode: String
    let data: [TripModel]
}

struct VoidResponse: Codable {}

struct TripRequest: Codable {
    let name: String
    let description: String?
    let startDate: String
    let endDate: String
    let address: String?
    let coverImage: Int?
    let isPublic: Bool
    
    enum CodingKeys: String, CodingKey {
        case name, description, address
        case startDate = "start_date"
        case endDate = "end_date"
        case coverImage = "cover_image"
        case isPublic = "is_public"
    }
}
