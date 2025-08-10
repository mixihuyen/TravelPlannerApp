struct PackingItem: Identifiable, Codable, Equatable {
    let id: Int
    var name: String
    var isPacked: Bool
    var isShared: Bool
    var userId: Int?
    var quantity: Int
    var note: String?

    init(id: Int = 0, name: String, isPacked: Bool, isShared: Bool, userId: Int? = nil, quantity: Int = 1, note: String? = nil) {
        self.id = id
        self.name = name
        self.isPacked = isPacked
        self.isShared = isShared
        self.userId = userId
        self.quantity = quantity
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case note
        case isShared = "is_shared"
        case isPacked = "is_packed"
        case userId = "user_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(isShared, forKey: .isShared)
        try container.encode(isPacked, forKey: .isPacked)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(note, forKey: .note)
    }
    static func == (lhs: PackingItem, rhs: PackingItem) -> Bool {
            return lhs.id == rhs.id &&
                   lhs.name == rhs.name &&
                   lhs.isPacked == rhs.isPacked &&
                   lhs.isShared == rhs.isShared &&
                   lhs.userId == rhs.userId &&
                   lhs.quantity == rhs.quantity &&
                   lhs.note == rhs.note
        }
}

struct PackingListResponse: Codable {
    let success: Bool
    let data: PackingListData
}

struct PackingListData: Codable {
    let tripItems: [PackingItemResponse]
}

struct PackingItemResponse: Codable {
    let id: Int
    let tripId: Int
    let userId: Int?
    let name: String
    let quantity: Int
    let isShared: Bool
    let isPacked: Bool
    let note: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, note, createdAt, updatedAt
        case tripId = "trip_id"
        case userId = "user_id"
        case isShared = "is_shared"
        case isPacked = "is_packed"
    }
}



struct CreatePackingItemRequest: Codable {
    let name: String
    let quantity: Int
    let isShared: Bool
    let isPacked: Bool
    let userId: Int?

    enum CodingKeys: String, CodingKey {
        case name, quantity
        case isShared = "is_shared"
        case isPacked = "is_packed"
        case userId = "user_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(isShared, forKey: .isShared)
        try container.encode(isPacked, forKey: .isPacked)
        if userId == nil {
            try container.encodeNil(forKey: .userId)
        } else {
            try container.encode(userId, forKey: .userId)
        }
    }
}

struct CreatePackingItemResponse: Codable {
    let success: Bool
    let data: PackingItemResponse
}


struct UpdatePackingItemResponse: Codable {
    let success: Bool
    let data: UpdatePackingItemData
}

struct UpdatePackingItemData: Codable {
    let updatedItem: PackingItemResponse
}
// MARK: - Codable Structs
struct UpdatePackingItemRequest: Codable {
    let name: String
    let quantity: Int
    let isShared: Bool
    let isPacked: Bool
    let userId: Int?

    enum CodingKeys: String, CodingKey {
        case name, quantity
        case isShared = "is_shared"
        case isPacked = "is_packed"
        case userId = "user_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(isShared, forKey: .isShared)
        try container.encode(isPacked, forKey: .isPacked)
        // Rõ ràng encode userId: nil thành "user_id": null
        if userId == nil {
            try container.encodeNil(forKey: .userId)
        } else {
            try container.encode(userId, forKey: .userId)
        }
    }
}
struct DeletePackingItemResponse: Codable {
    let success: Bool
    let message: String
}
