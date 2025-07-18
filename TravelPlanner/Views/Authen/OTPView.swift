import SwiftUI
struct OTPView: View {
    var email: String
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var navManager: NavigationManager
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = OTPViewModel()
    @FocusState private var focusedField: Int?
    var body: some View {
        ZStack (alignment: .topLeading){
            Color.background2.ignoresSafeArea()
            VStack {
                Image(horizontalSizeClass == .regular ? "big" : "banner")
                    .resizable()
                    .ignoresSafeArea(edges: .all)
                    .frame(height: horizontalSizeClass == .regular ? 600 : 391)
                Spacer()
            }
            Button(action: {
                navManager.goBack()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 26))
                    
                }
                .padding()
                .cornerRadius(12)
                .padding(.leading, 16)
            }
            VStack {
                Spacer()
                HStack{
                    VStack (alignment: .leading, spacing: 8){
                        Text("Xác thực mã của bạn")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("Nhập mật mã bạn vừa nhận được vào địa chỉ email \(email) ")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                
                
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { i in
                            TextField("", text: Binding(
                                get: { viewModel.otp[i] },
                                set: { viewModel.otp[i] = String($0.prefix(1)) }
                            ))
                            .frame(width: 50, height: 50)
                            .font(.title)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.Button, lineWidth: 1)) // Thay bằng Color.blue nếu thiếu
                            .focused($focusedField, equals: i)
                            .onChange(of: viewModel.otp[i]) { newValue in
                                if newValue.count == 1 && i < 3 {
                                    focusedField = i + 1 // Chuyển sang ô tiếp theo
                                } else if newValue.isEmpty && i > 0 {
                                    focusedField = i - 1 // Quay lại ô trước
                                } else if i == 3 && newValue.count == 1 {
                                    focusedField = nil // Bỏ focus khi ô cuối được điền
                                }
                            }
                        }
                    }
                    Text(String(format: "0:%02d", viewModel.timeRemaining))
                        .foregroundColor(.white)
                        .padding(.top, 32)
                    HStack(spacing: 10) {
                        Text("Không nhận được mã?")
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                        Button(action: {
                            viewModel.resendCode()
                        }) {
                            Text("Gửi lại")
                                .foregroundColor(viewModel.isResendEnabled ? .pink : .gray)
                                .font(.system(size: 14, weight: .bold))
                        }
                        .disabled(!viewModel.isResendEnabled)
                        
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 32)
                    Button(action: {
                        viewModel.submitOTP()
                    }) {
                        Text("Xác nhận")
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundColor(.white)
                            .frame(width: 275, height: 50)
                            .background(Color.Button)
                            .cornerRadius(25)
                    }
                }
                .padding(.vertical, 16)
                
                
                
                Spacer()
            }
            
            .padding(.horizontal, 32)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            viewModel.email = email
            viewModel.startTimer()
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                focusedField = 0
            }
            viewModel.navManager = navManager
            viewModel.authManager = authManager
        }
        .onDisappear {
            viewModel.invalidateTimer()
        }
        .alert(isPresented: Binding<Bool>(
                    get: { viewModel.alertMessage != nil },
                    set: { _ in viewModel.alertMessage = nil }
        )) {
            Alert(
                title: Text("Thông báo"),
                message: Text(viewModel.alertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
        
        
    }
    
}

