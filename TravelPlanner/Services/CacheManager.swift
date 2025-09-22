import Foundation
import CoreData

class CacheManager {
    static let shared = CacheManager()
    private let coreDataStack = CoreDataStack.shared
    
    // Danh sách các khóa UserDefaults được sử dụng trong ứng dụng
    private let userDefaultsKeys: [String] = [
        "authToken","refreshToken", "firstName", "lastName", "username", "userEmail", "userId",
        "trips_cache_timestamp", "next_temp_id",
        "dashboard_cache_",
        "participants_",
        "packing_list_cache_timestamp_", "next_temp_packing_id_", "pending_packing_items_"
        
    ]
    
    // Danh sách các entity Core Data cần xóa
    private let coreDataEntities: [String] = [
        "TripEntity", "TripDayEntity", "PackingItemEntity"
    ]
    
    private init() {}
    
    // Xóa toàn bộ cache
    func clearAllCache() {
        // Xóa tất cả UserDefaults keys
        for key in userDefaultsKeys {
            if key.contains("_") {
                // Xử lý prefix keys (cần xóa tất cả keys có prefix)
                let allKeys = UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasPrefix(key) }
                for prefixedKey in allKeys {
                    UserDefaults.standard.removeObject(forKey: prefixedKey)
                    print("🗑️ Đã xóa UserDefaults key: \(prefixedKey)")
                }
            } else {
                UserDefaults.standard.removeObject(forKey: key)
                print("🗑️ Đã xóa UserDefaults key: \(key)")
            }
        }
        
        // Xóa tất cả Core Data entities
        for entity in coreDataEntities {
            clearCoreData(entityName: entity)
        }
        
        // Xóa RAM cache cho ParticipantViewModel
        ParticipantViewModel.ramCache = [:]
        
        print("🗑️ Đã xóa toàn bộ cache")
    }
    
    // Xóa cache Core Data cho một entity cụ thể
    private func clearCoreData(entityName: String) {
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            coreDataStack.saveContext()
            print("🗑️ Đã xóa cache Core Data cho entity: \(entityName)")
        } catch {
            print("❌ Lỗi khi xóa Core Data cho entity \(entityName): \(error.localizedDescription)")
        }
    }
    
    // Lưu timestamp cache
    func saveCacheTimestamp(forKey key: String) {
        UserDefaults.standard.set(Date(), forKey: key)
    }
    
    // Lấy timestamp cache
    func loadCacheTimestamp(forKey key: String) -> Date? {
        return UserDefaults.standard.object(forKey: key) as? Date
    }
    
    // Xóa cache cho key cụ thể (cho prefix keys)
    func clearCache(forKeyPrefix prefix: String) {
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
        for key in allKeys {
            UserDefaults.standard.removeObject(forKey: key)
            print("🗑️ Đã xóa cache cho key: \(key)")
        }
    }
}
