import Foundation
import CoreData


struct ImageData: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let imagetableId: Int?
    let imagetableType: String?
    let url: String
    let publicId: String
    let altText: String?
    let status: String
    let createdByUserId: Int
    let createdAt: String
    let updatedAt: String
    var createdByUser: UserInformation?
    var imageData: Data? // Thêm để lưu dữ liệu ảnh
    
    enum CodingKeys: String, CodingKey {
        case id, imagetableId, imagetableType, url, publicId = "public_id"
        case altText = "alt_text", status, createdByUserId = "created_by_user_id"
        case createdAt, updatedAt, createdByUser = "created_by_user"
    }
    
    static func == (lhs: ImageData, rhs: ImageData) -> Bool {
        return lhs.id == rhs.id &&
               lhs.imagetableId == rhs.imagetableId &&
               lhs.imagetableType == rhs.imagetableType &&
               lhs.url == rhs.url &&
               lhs.publicId == rhs.publicId &&
               lhs.altText == rhs.altText &&
               lhs.status == rhs.status &&
               lhs.createdByUserId == rhs.createdByUserId &&
               lhs.createdAt == rhs.createdAt &&
               lhs.updatedAt == rhs.updatedAt
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(imagetableId)
        hasher.combine(imagetableType)
        hasher.combine(url)
        hasher.combine(publicId)
        hasher.combine(altText)
        hasher.combine(status)
        hasher.combine(createdByUserId)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
    }
    
    func toEntity(context: NSManagedObjectContext) -> ImageEntity {
        let entity = ImageEntity(context: context)
        entity.id = Int32(id)
        entity.url = url
        entity.imagetableId = imagetableId != nil ? Int32(imagetableId!) : 0
        entity.imagetableType = imagetableType
        entity.publicId = publicId
        entity.altText = altText
        entity.status = status
        entity.createdByUserId = Int32(createdByUserId)
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        entity.cachedAt = Date()
        entity.imageData = imageData // Lưu dữ liệu ảnh
        
        if let user = createdByUser {
            do {
                let userData = try JSONEncoder().encode(user)
                entity.createdByUser = userData
                print("💾 Encoded createdByUser for imageId=\(id): \(user.username ?? "N/A")")
            } catch {
                print("❌ Error encoding createdByUser for imageId=\(id): \(error)")
                entity.createdByUser = nil
            }
        } else {
            print("⚠️ No createdByUser to encode for imageId=\(id)")
            entity.createdByUser = nil
        }
        return entity
    }
    
    func toUserImageEntity(context: NSManagedObjectContext) -> UserImageEntity {
        let entity = UserImageEntity(context: context)
        entity.id = Int32(id)
        entity.url = url
        entity.imagetableId = imagetableId != nil ? Int32(imagetableId!) : 0
        entity.imagetableType = imagetableType
        entity.publicId = publicId
        entity.altText = altText
        entity.status = status
        entity.createdByUserId = Int32(createdByUserId)
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        entity.cachedAt = Date()
        entity.imageData = imageData // Lưu dữ liệu ảnh
        return entity
    }
    
    init(from entity: ImageEntity) {
        self.id = Int(entity.id)
        self.imagetableId = entity.imagetableId != 0 ? Int(entity.imagetableId) : nil
        self.imagetableType = entity.imagetableType
        self.url = entity.url ?? ""
        self.publicId = entity.publicId ?? ""
        self.altText = entity.altText
        self.status = entity.status ?? ""
        self.createdByUserId = Int(entity.createdByUserId)
        self.createdAt = entity.createdAt ?? ""
        self.updatedAt = entity.updatedAt ?? ""
        self.imageData = entity.imageData // Lấy dữ liệu ảnh từ CoreData
        
        if let userData = entity.createdByUser {
            do {
                let user = try JSONDecoder().decode(UserInformation.self, from: userData)
                self.createdByUser = user
                print("📂 Decoded createdByUser for imageId=\(id): \(user.username ?? "N/A")")
            } catch {
                print("❌ Error decoding createdByUser for imageId=\(id): \(error)")
                self.createdByUser = nil
            }
        } else {
            self.createdByUser = nil
        }
    }
    
    init(from userEntity: UserImageEntity) {
        self.id = Int(userEntity.id)
        self.imagetableId = userEntity.imagetableId != 0 ? Int(userEntity.imagetableId) : nil
        self.imagetableType = userEntity.imagetableType
        self.url = userEntity.url ?? ""
        self.publicId = userEntity.publicId ?? ""
        self.altText = userEntity.altText
        self.status = userEntity.status ?? ""
        self.createdByUserId = Int(userEntity.createdByUserId)
        self.createdAt = userEntity.createdAt ?? ""
        self.updatedAt = userEntity.updatedAt ?? ""
        self.imageData = userEntity.imageData // Lấy dữ liệu ảnh từ CoreData
    }
}


struct ImageUploadResponse: Codable {
    let success: Bool
    let message: String
    let statusCode: Int
    let reasonStatusCode: String
    let data: ImageData
    
    
}
struct ImageDeleteResponse: Codable {
    let success: Bool
    let message: String
    let statusCode: Int
    let reasonStatusCode: String
    let data: String
}

struct ImageListResponse: Codable {
    let success: Bool
    let message: String
    let statusCode: Int
    let reasonStatusCode: String
    let data: [ImageData]
    let totalPages: Int?
    let totalItems: Int?
    let currentPage: Int?
}
