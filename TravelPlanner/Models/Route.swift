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
    case tripDetailView(tripId: Int)
    case createTrip
    case editTrip(trip: TripModel)
    case tabBarView(tripId: Int)
    case activity(tripId: Int, tripDayId: Int)
    case addActivity(tripId: Int, tripDayId: Int)
    case editActivity(tripId: Int, tripDayId: Int, activity: TripActivity)
    case activityImages(tripId: Int, tripDayId: Int, activityId: Int)
    
}
