//
//  Entity+CoreDataProperties.swift
//  TravelPlanner
//
//  Created by Mixi Huyen on 17/8/25.
//
//

import Foundation
import CoreData


extension Entity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Entity> {
        return NSFetchRequest<Entity>(entityName: "Entity")
    }

    @NSManaged public var id: Int32
    @NSManaged public var tripId: Int32
    @NSManaged public var name: String?
    @NSManaged public var quantity: Int32
    @NSManaged public var isPacked: Bool
    @NSManaged public var isShared: Bool
    @NSManaged public var userId: Int32
    @NSManaged public var note: Int32

}

extension Entity : Identifiable {

}
