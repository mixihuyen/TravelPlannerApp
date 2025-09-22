
import Foundation
import CoreData

struct PackingItem: Identifiable, Codable, Equatable {
    let id: Int
    var name: String
    var isPacked: Bool
    var isShared: Bool
    var createdByUserId: Int
    var assignedToUserId: Int? // Giữ là Int?
    var quantity: Int
    var note: String?

    init(id: Int = 0, name: String, isPacked: Bool, isShared: Bool, createdByUserId: Int, assignedToUserId: Int? = nil, quantity: Int = 1, note: String? = nil) {
        self.id = id
        self.name = name
        self.isPacked = isPacked
        self.isShared = isShared
        self.createdByUserId = createdByUserId
        self.assignedToUserId = assignedToUserId
        self.quantity = quantity
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, note
        case isShared = "is_shared"
        case isPacked = "is_packed"
        case createdByUserId = "created_by_user_id"
        case assignedToUserId = "assigned_to_user_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(isShared, forKey: .isShared)
        try container.encode(isPacked, forKey: .isPacked)
        try container.encode(createdByUserId, forKey: .createdByUserId)
        try container.encodeIfPresent(assignedToUserId, forKey: .assignedToUserId)
        try container.encodeIfPresent(note, forKey: .note)
    }

    static func == (lhs: PackingItem, rhs: PackingItem) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.isPacked == rhs.isPacked &&
               lhs.isShared == rhs.isShared &&
               lhs.createdByUserId == rhs.createdByUserId &&
               lhs.assignedToUserId == rhs.assignedToUserId &&
               lhs.quantity == rhs.quantity &&
               lhs.note == rhs.note
    }

    init(from entity: PackingItemEntity) {
        self.id = Int(entity.id)
        self.name = entity.name ?? ""
        self.isPacked = entity.isPacked
        self.isShared = entity.isShared
        self.createdByUserId = Int(entity.createdByUserId)
        let assignedId = Int(entity.assignedToUserId)
        self.assignedToUserId = assignedId != 0 ? assignedId : nil // Chuyển 0 thành nil
        self.quantity = Int(entity.quantity)
        self.note = entity.note
    }

    func toEntity(context: NSManagedObjectContext, tripId: Int) -> PackingItemEntity {
        let entity = PackingItemEntity(context: context)
        entity.id = Int32(id)
        entity.tripId = Int32(tripId)
        entity.name = name
        entity.quantity = Int32(quantity)
        entity.isPacked = isPacked
        entity.isShared = isShared
        entity.createdByUserId = Int32(createdByUserId)
        entity.assignedToUserId = Int32(assignedToUserId ?? 0) // Chuyển nil thành 0
        entity.note = note
        return entity
    }
}


struct PendingItem: Codable {
    enum Action: String, Codable {
        case create, update, delete
    }
    let item: PackingItem
    let action: Action
}

struct PackingListResponse: Codable {
    let success: Bool
    let message: String
    let statusCode: Int
    let reasonStatusCode: String
    let data: [PackingItemResponse]

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case statusCode = "statusCode"
        case reasonStatusCode = "reasonStatusCode"
        case data
    }
}

struct PackingItemResponse: Codable {
    let id: Int
    let tripId: Int
    let createdByUserId: Int
    let assignedToUserId: Int?
    let name: String
    let quantity: Int
    let isShared: Bool
    let isPacked: Bool
    let note: String?
    let createdAt: String
    let updatedAt: String
    let createdByUser: UserInformation?
    let assignedToUser: UserInformation?

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, note, createdAt, updatedAt
        case tripId = "trip_id"
        case createdByUserId = "created_by_user_id"
        case assignedToUserId = "assigned_to_user_id"
        case createdByUser = "created_by_user"
        case assignedToUser = "assigned_to_user"
        case isShared = "is_shared"
        case isPacked = "is_packed"
    }
}

struct CreatePackingItemRequest: Codable {
    let name: String
    let quantity: Int
    let isShared: Bool
    let isPacked: Bool
    let assignedToUserId: Int?

    enum CodingKeys: String, CodingKey {
        case name, quantity
        case isShared = "is_shared"
        case isPacked = "is_packed"
        case assignedToUserId = "assigned_to_user_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(isShared, forKey: .isShared)
        try container.encode(isPacked, forKey: .isPacked)
        if assignedToUserId == nil {
            try container.encodeNil(forKey: .assignedToUserId)
        } else {
            try container.encode(assignedToUserId, forKey: .assignedToUserId)
        }
    }
}

struct CreatePackingItemResponse: Codable {
    let success: Bool
    let data: PackingItemResponse
}

struct UpdatePackingItemResponse: Codable {
    let success: Bool
    let message: String
    let statusCode: Int
    let reasonStatusCode: String
    let data: PackingItemResponse

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case statusCode = "statusCode"
        case reasonStatusCode = "reasonStatusCode"
        case data
    }
}

struct UpdatePackingItemRequest: Codable {
    let name: String
    let quantity: Int
    let isShared: Bool
    let isPacked: Bool
    let assignedToUserId: Int?

    enum CodingKeys: String, CodingKey {
        case name, quantity
        case isShared = "is_shared"
        case isPacked = "is_packed"
        case assignedToUserId = "assigned_to_user_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(isShared, forKey: .isShared)
        try container.encode(isPacked, forKey: .isPacked)
        if assignedToUserId == nil {
            try container.encodeNil(forKey: .assignedToUserId)
        } else {
            try container.encode(assignedToUserId, forKey: .assignedToUserId)
        }
    }
}

struct DeletePackingItemResponse: Codable {
    let success: Bool
    let message: String
}
