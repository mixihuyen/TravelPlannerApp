import Foundation
import SwiftUI

enum Route: Hashable {
    case register
    case signin
    case verifyEmail
    case otpview(email: String)
    case nameView
    case usernameView
    case homeTabBar
    case tripView
    case tripDetailView(trip: TripModel)
    case createTrip
    case editTrip(trip: TripModel)
    case tabBarView(trip: TripModel)
    case activity(date: Date, activities: [TripActivity], trip: TripModel, tripDayId: Int)
    case addActivity(date: Date, trip: TripModel, tripDayId: Int)
    case editActivity(date: Date, activity: TripActivity, trip: TripModel, tripDayId: Int)
    
    
}
