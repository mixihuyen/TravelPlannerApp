import SwiftUI

struct VerifyView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var navManager: NavigationManager
    @StateObject private var viewModel = VerifyViewModel()
    
    var body: some View {
        ZStack(alignment: .topLeading) {
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
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.system(size: 26))
                    .padding()
                    .cornerRadius(12)
                    .padding(.leading, 16)
            }
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 16) {
                    Spacer()
                    
                    Text("Email của bạn là gì?")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    CustomTextField(placeholder: "Nhập email", text: $viewModel.email, keyboardType: .emailAddress, autocapitalization: .never)
                    
                    Text("Bạn cần xác nhận email này sau.")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                    HStack {
                        Spacer()
                        if viewModel.isLoading {
                            LottieView(animationName: "loading")
                                .frame(width: 200, height: 50)
                                .padding(.top, 32)
                        } else {
                            Button(action: {
                                viewModel.verifyEmail()
                            }) {
                                Text("Tiếp")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 100, height: 50)
                                    .background(Color.Button)
                                    .cornerRadius(25)
                            }
                            .padding(.top, 32)
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.horizontal, 32)

            .frame(maxWidth: horizontalSizeClass == .regular ? 600 : .infinity)
                Spacer()
            }
                
            
            
            
        }
        .navigationBarBackButtonHidden(true)
        .background(
            NavigationLink(
                destination: OTPView(email: viewModel.email),
                isActive: $viewModel.shouldNavigateToOTP
            ) {
                EmptyView()
            }
        )
        .alert(isPresented: Binding<Bool>(
            get: { viewModel.alertMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.alertMessage = nil
                }
            }
        )) {
            Alert(
                title: Text("Lỗi"),
                message: Text(viewModel.alertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }

    }
}

#Preview {
    VerifyView()
}
