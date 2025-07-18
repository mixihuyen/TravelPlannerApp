import SwiftUI

struct NameView: View {
    @State private var firstname: String = ""
    @State private var lastname: String = ""
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
                Text("Tên của bạn là gì?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                CustomTextField(placeholder: "Họ", text: $firstname, autocapitalization: .words)

                CustomTextField(placeholder: "Tên", text: $lastname, autocapitalization: .words)

                Button(action: {
                    if firstname.trimmingCharacters(in: .whitespaces).isEmpty ||
                        lastname.trimmingCharacters(in: .whitespaces).isEmpty {
                        alertMessage = "Vui lòng nhập đầy đủ họ và tên."
                        showAlert = true
                        return
                    }

                    isLoading = true
                    AuthService.updateUserProfile(firstName: firstname, lastName: lastname, username: nil) { success, message in
                        if success {
                            navManager.go(to: .usernameView)
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

#Preview {
    NameView()
        .environmentObject(NavigationManager())
}
