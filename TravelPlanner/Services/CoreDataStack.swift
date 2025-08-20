import CoreData

class CoreDataStack {
    static let shared = CoreDataStack()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "TripModel") 
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("❌ Failed to load persistent stores: \(error), \(error.userInfo)")
            } else {
                container.viewContext.automaticallyMergesChangesFromParent = true
                print("✅ Successfully loaded Core Data persistent stores")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("💾 Đã lưu Core Data")
            } catch {
                print("Lỗi lưu Core Data: \(error.localizedDescription)")
            }
        }
    }
}
