//
//  PackingItemEntity+CoreDataProperties.swift
//  TravelPlanner
//
//  Created by Mixi Huyen on 17/8/25.
//
//

import Foundation
import CoreData


extension PackingItemEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PackingItemEntity> {
        return NSFetchRequest<PackingItemEntity>(entityName: "PackingItemEntity")
    }

    @NSManaged public var id: Int32
    @NSManaged public var isPacked: Bool
    @NSManaged public var isShared: Bool
    @NSManaged public var name: String?
    @NSManaged public var note: String?
    @NSManaged public var quantity: Int32
    @NSManaged public var tripId: Int32
    @NSManaged public var userId: Int32

}

extension PackingItemEntity : Identifiable {

}
