import SwiftUI
import Combine

struct EditProfileView: View {
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var username: String = ""
    @State private var isLoading: Bool = false
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    @State private var cancellables = Set<AnyCancellable>()
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            VStack{
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20))
                        Spacer()
                        Text("Chỉnh sửa thông tin cá nhân")
                            .font(.system(size: 18, weight: .bold))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.top, 15)

                // Hiển thị chữ cái đầu của tên người dùng
                Circle()
                    .fill(Color.pink)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Text(profileViewModel.avatarInitials())
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    )
                    .padding(.bottom, 8)
                    .padding(.top, 40)
                VStack(alignment: .leading){
                    Text("Họ")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                    CustomTextField(placeholder: "Họ", text: $firstName, autocapitalization: .words)
                        .padding(.bottom, 10)
                    Text("Tên")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                    CustomTextField(placeholder: "Tên", text: $lastName, autocapitalization: .words)
                        .padding(.bottom, 10)
                    Text("Tên người dùng")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                    CustomTextField(placeholder: "Tên người dùng", text: $username, autocapitalization: .never)
                        .padding(.bottom, 10)
                }
                
                    Button(action: {
                        guard validateInputs() else { return }
                        isLoading = true
                        profileViewModel.updateUserProfile(firstName: firstName, lastName: lastName, username: username) { success in
                            isLoading = false
                            if success {
                                alertMessage = "Cập nhật thông tin thành công!"
                                showAlert = true
                                NotificationCenter.default.post(name: NSNotification.Name("UserProfileUpdated"), object: nil)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    dismiss()
                                }
                            } else {
                                alertMessage = profileViewModel.toastMessage ?? "Lỗi không xác định"
                                showAlert = true
                            }
                        }
                    }) {
                        if isLoading {
                            LottieView(animationName: "loading")
                                .frame(width: 200, height: 50)
                                .padding(.top, 32)
                        } else {
                            Text("Lưu")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .bold))
                                .frame(maxWidth: 100)
                                .frame(height: 50)
                                .background(Color.Button)
                                .cornerRadius(25)
                        }
                    }
                    
                .padding(.top, 32)
                Spacer()
                
            }
            .padding(.horizontal, 32)
        }
        .navigationBarBackButtonHidden(true)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertMessage == "Cập nhật thông tin thành công!" ? "Thành công" : "Lỗi"),
                message: Text(alertMessage ?? "Đã xảy ra lỗi không xác định"),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            firstName = profileViewModel.userInfo?.firstName ?? ""
            lastName = profileViewModel.userInfo?.lastName ?? ""
            username = profileViewModel.userInfo?.username ?? ""
        }
    }

    private func validateInputs() -> Bool {
        if firstName.trimmingCharacters(in: .whitespaces).isEmpty {
            alertMessage = "Vui lòng nhập họ."
            showAlert = true
            return false
        }
        if lastName.trimmingCharacters(in: .whitespaces).isEmpty {
            alertMessage = "Vui lòng nhập tên."
            showAlert = true
            return false
        }
        if username.trimmingCharacters(in: .whitespaces).isEmpty {
            alertMessage = "Vui lòng nhập tên người dùng."
            showAlert = true
            return false
        }
        return true
    }
}
