import SwiftUI

struct UserNameView: View {
    @State private var username: String = ""
    @State private var isLoading: Bool = false
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var navManager: NavigationManager

    var body: some View {
        ZStack {
            Color.background2.ignoresSafeArea()

            VStack {
                Image(horizontalSizeClass == .regular ? "big" : "banner")
                    .resizable()
                    .ignoresSafeArea(edges: .all)
                    .frame(height: horizontalSizeClass == .regular ? 600 : 391)
                Spacer()
            }

            VStack(spacing: 20) {
                Text("Chọn một tên người dùng")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                CustomTextField(placeholder: "Tên người dùng", text: $username)

                HStack {
                    Text("Việc này sẽ giúp bạn bè của bạn tìm thấy bạn trên Travel Planner!")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                }

                Button(action: {
                    guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
                        alertMessage = "Vui lòng nhập tên người dùng."
                        showAlert = true
                        return
                    }

                    isLoading = true
                    AuthService.updateUserProfile(firstName: nil, lastName: nil, username: username) { success, message in
                        if success {
                            navManager.go(to: .homeTabBar)
                        } else {
                            alertMessage = message
                            showAlert = true
                        }
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .frame(width: 100, height: 50)
                    } else {
                        Text("Tiếp")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .bold))
                            .frame(maxWidth: 100)
                            .frame(height: 50)
                            .background(Color.Button)
                            .cornerRadius(25)
                    }
                }
                .disabled(username.isEmpty)
                .padding(.top, 32)
            }
            .padding(.horizontal, 32)
        }
        .navigationBarBackButtonHidden(true)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Lỗi"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }
}
