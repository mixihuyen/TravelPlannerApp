import Foundation


struct ImageData: Codable, Identifiable, Equatable, Hashable{
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
    let createdByUser: UserInformation?
    
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
    
}
