import Foundation

enum Route: Hashable {
    case register
    case signin
    case verifyEmail
    case otpview(email: String)
    case nameView
    case usernameView
    case homeTabBar
    case tripView
    case createTrip
    case tabBarView(trip: TripModel)
    case activity(date: Date, activities: [TripActivity])
    
    
}
