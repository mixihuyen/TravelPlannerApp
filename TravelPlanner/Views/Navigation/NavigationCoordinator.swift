import Foundation
import SwiftUI

class NavigationCoordinator: ObservableObject {
    @Published var pendingTripId: Int?
    @Published var showJoinAlert: Bool = false
    @Published var shouldRefreshTrips: Bool = false 
}
