import SwiftUI
import Combine

struct NameView: View {
    @State private var firstname: String = ""
    @State private var lastname: String = ""
    @State private var isLoading: Bool = false
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    @State private var cancellables = Set<AnyCancellable>()
    @EnvironmentObject var authManager: AuthManager

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var navManager: NavigationManager
    
    // Tạo instance của AuthService
    private let authService = AuthService()

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
                    
                    // Sử dụng instance authService để gọi updateUserProfile
                    authService.updateUserProfile(firstName: firstname, lastName: lastname, username: nil)
                        .receive(on: DispatchQueue.main)
                        .sink { completion in
                            isLoading = false
                            switch completion {
                            case .failure(let error):
                                alertMessage = error.localizedDescription
                                showAlert = true
                            case .finished:
                                break
                            }
                        } receiveValue: { response in
                            if response.success && (200...299).contains(response.statusCode) {
                                UserDefaults.standard.set(firstname, forKey: "firstName")
                                UserDefaults.standard.set(lastname, forKey: "lastName")
                                authManager.currentUserName = [firstname, lastname].joined(separator: " ").trimmingCharacters(in: .whitespaces)
                                navManager.go(to: .usernameView)
                            } else {
                                alertMessage = response.message
                                showAlert = true
                            }
                        }
                        .store(in: &cancellables)
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
            Alert(title: Text("Lỗi"), message: Text(alertMessage ?? "Đã xảy ra lỗi không xác định"), dismissButton: .default(Text("OK")))
        }
    }
}
