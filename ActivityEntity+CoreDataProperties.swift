//
//  ActivityEntity+CoreDataProperties.swift
//  TravelPlanner
//
//  Created by Mixi Huyen on 18/9/25.
//
//

import Foundation
import CoreData


extension ActivityEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ActivityEntity> {
        return NSFetchRequest<ActivityEntity>(entityName: "ActivityEntity")
    }

    @NSManaged public var id: Int64
    @NSManaged public var tripId: Int64
    @NSManaged public var tripDayId: Int64
    @NSManaged public var startTime: String?
    @NSManaged public var endTime: String?
    @NSManaged public var activity: String?
    @NSManaged public var address: String?
    @NSManaged public var estimatedCost: Double
    @NSManaged public var actualCost: Double
    @NSManaged public var note: String?
    @NSManaged public var createdAt: String?
    @NSManaged public var updatedAt: String?

}

extension ActivityEntity : Identifiable {

}
