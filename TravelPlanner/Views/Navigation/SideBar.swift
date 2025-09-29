import SwiftUI

struct SideBar: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var navManager: NavigationManager
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @State private var isShowingEditProfile: Bool = false
    @State private var showLogoutAlert: Bool = false // Thêm state cho alert xác nhận
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
                            Text(profileViewModel.avatarInitials())
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profileViewModel.userFullName())
                            .font(.title3)
                            .bold()
                            .foregroundColor(.white)

                        Text("@\(profileViewModel.userInfo?.username ?? "username")")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    NavigationLink(
                        destination: EditProfileView()
                            .environmentObject(profileViewModel),
                        isActive: $isShowingEditProfile
                    ) {
                        Image(systemName: "square.and.pencil.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                    }
                }
                .padding(.bottom, 10)

                Divider()
                    .background(Color.white.opacity(0.4))
                
                HStack {
                    Spacer()
                    // Logout
                    Button(action: {
                        showLogoutAlert = true // Hiển thị alert xác nhận
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
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("Xác Nhận Đăng Xuất"),
                message: Text("Bạn có chắc chắn muốn đăng xuất?"),
                primaryButton: .destructive(Text("Đăng Xuất")) {
                    print("🚪 User confirmed logout")
                    authManager.logout()
                    onLogout()
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }
}
