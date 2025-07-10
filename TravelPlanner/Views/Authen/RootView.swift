import SwiftUI

struct RootView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            FirstView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .register:
                        RegisterView(path: $path)
                    case .signin:
                        SignInView(path: $path)
                    }
                }
        }
    }
}

enum Route: Hashable {
    case register
    case signin
}
