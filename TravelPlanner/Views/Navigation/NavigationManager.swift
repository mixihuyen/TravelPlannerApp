import SwiftUI

class NavigationManager: ObservableObject {
    @Published var path = NavigationPath()
    
    func go(to route: Route) {
        print("Navigating to: \(route)")
        path.append(route)
    }
    
    func goBack() {
        print("Going back")
        path.removeLast()
    }
    
    func goToRoot() {
        print("Going to root")
        path.removeLast(path.count)
    }
}
