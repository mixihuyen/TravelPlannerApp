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
    case tabBarView(trip: TripModel)
    case activity(date: Date, activities: [TripActivity], trip: TripModel, tripDayId: Int)
    case addActivity(date: Date, trip: TripModel, tripDayId: Int)
    case editActivity(date: Date, activity: TripActivity, trip: TripModel, tripDayId: Int)
    
    // Đảm bảo Hashable
    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.register, .register),
             (.signin, .signin),
             (.verifyEmail, .verifyEmail),
             (.nameView, .nameView),
             (.usernameView, .usernameView),
             (.homeTabBar, .homeTabBar),
             (.tripView, .tripView),
             (.createTrip, .createTrip):
            return true
        case (.otpview(let email1), .otpview(let email2)):
            return email1 == email2
        case (.tripDetailView(let trip1), .tripDetailView(let trip2)):
            return trip1.id == trip2.id
        case (.tabBarView(let trip1), .tabBarView(let trip2)):
            return trip1.id == trip2.id
        case (.activity(let date1, let activities1, let trip1, let tripDayId1), .activity(let date2, let activities2, let trip2, let tripDayId2)):
            return date1 == date2 && activities1 == activities2 && trip1.id == trip2.id && tripDayId1 == tripDayId2
        case (.addActivity(let date1, let trip1, let tripDayId1), .addActivity(let date2, let trip2, let tripDayId2)):
            return date1 == date2 && trip1.id == trip2.id && tripDayId1 == tripDayId2
        case (.editActivity(let date1, let activity1, let trip1, let tripDayId1), .editActivity(let date2, let activity2, let trip2, let tripDayId2)):
            return date1 == date2 && activity1.id == activity2.id && trip1.id == trip2.id && tripDayId1 == tripDayId2
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .register:
            hasher.combine("register")
        case .signin:
            hasher.combine("signin")
        case .verifyEmail:
            hasher.combine("verifyEmail")
        case .otpview(let email):
            hasher.combine("otpview")
            hasher.combine(email)
        case .nameView:
            hasher.combine("nameView")
        case .usernameView:
            hasher.combine("usernameView")
        case .homeTabBar:
            hasher.combine("homeTabBar")
        case .tripView:
            hasher.combine("tripView")
        case .tripDetailView(let trip):
            hasher.combine("tripDetailView")
            hasher.combine(trip.id)
        case .createTrip:
            hasher.combine("createTrip")
        case .tabBarView(let trip):
            hasher.combine("tabBarView")
            hasher.combine(trip.id)
        case .activity(let date, let activities, let trip, let tripDayId):
            hasher.combine("activity")
            hasher.combine(date)
            hasher.combine(activities)
            hasher.combine(trip.id)
            hasher.combine(tripDayId)
        case .addActivity(let date, let trip, let tripDayId):
            hasher.combine("addActivity")
            hasher.combine(date)
            hasher.combine(trip.id)
            hasher.combine(tripDayId)
        case .editActivity(let date, let activity, let trip, let tripDayId):
            hasher.combine("editActivity")
            hasher.combine(date)
            hasher.combine(activity.id)
            hasher.combine(trip.id)
            hasher.combine(tripDayId)
        }
    }
}
