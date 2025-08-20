import SwiftUI

struct SideBar: View {
    @EnvironmentObject var authManager: AuthManager
    let onLogout: () -> Void

    var body: some View {
        ZStack {
            // Gradient background
            Color.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 30) {
                // Profile Header
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.pink)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(authManager.avatarInitials())
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(authManager.currentUserName ?? "Khách")
                            .font(.title3)
                            .bold()
                            .foregroundColor(.white)

                        let username = authManager.username ?? "username"
                        Text("@\(username)" ?? "Chưa đăng nhập")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.bottom, 10)

                Divider()
                    .background(Color.white.opacity(0.4))
                HStack {
                    Spacer()
                    // Logout
                    Button(action: {
                        authManager.logout()
                        onLogout()
                    }) {
                        HStack {
                            Text("Đăng xuất")
                                .font(.system(size: 16))
                            Image(systemName: "rectangle.portrait.and.arrow.forward.fill")
                            
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .clipShape(Capsule())
                    }
                    .padding(.bottom, 40)
                    Spacer()
                }
                Spacer()
                

                
            }
            .padding()
        }
        .frame(maxWidth: 280, maxHeight: .infinity, alignment: .topLeading)
    }
}



struct SideBar_Previews: PreviewProvider {
    static var previews: some View {
        SideBar {
            print("Đăng xuất")
        }
        .environmentObject(AuthManager())
        .environmentObject(NavigationManager())
    }
}
