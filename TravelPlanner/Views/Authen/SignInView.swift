
import SwiftUI
struct SignInView : View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var navManager: NavigationManager
    var body: some View {
        ZStack (alignment: .topLeading) {
            Color.background2.ignoresSafeArea()
            VStack {
                Image(horizontalSizeClass == .regular ? "big" : "banner")
                    .resizable()
                    .ignoresSafeArea(edges: .all)
                    .frame(height: horizontalSizeClass == .regular ? 600 : 391)
                Spacer()
            }
            Button(action: {
                navManager.goToRoot()
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
            HStack {
                Spacer()
                VStack{
                    Spacer()
                    Text("Welcome Back!")
                        .font(.system(size: horizontalSizeClass == .regular ? 68 : 36))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Đăng nhập vào Travel Planner")
                        .font(.system(size: horizontalSizeClass == .regular ? 28 : 15))
                        .foregroundColor(.white)
                        .padding(.bottom, horizontalSizeClass == .regular ? 38 : 0)
                    VStack(spacing: 16) {
                        LoginButton(icon: "envelope.fill", text: "Tiếp tục email"){
                            navManager.go(to:.verifyEmail)
                        }
                        LoginButton(icon: "phone.fill", text: "Tiếp tục bằng số điện thoại"){
                            navManager.go(to:.verifyEmail)
                        }
                        LoginButton(icon: "logo-facebook", text: "Tiếp tục với Facebook"){
                            navManager.go(to:.verifyEmail)
                        }
                        LoginButton(icon: "apple.logo", text: "Tiếp tục với Apple"){
                            navManager.go(to:.verifyEmail)
                        }
                        LoginButton(icon: "logo-google", text: "Tiếp tục với Google"){
                            navManager.go(to:.verifyEmail)
                        }
                    }
                    .padding(.top ,32)
                    VStack{
                        Text("Bạn chưa có tài khoản?")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                        Button {
                            navManager.go(to:.register)
                        } label: {
                            Text("Đăng ký")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.bottom, horizontalSizeClass == .regular ? 200 : 0)
                        }
                    }
                    .padding(.vertical, 32)
                    
                }
                .padding(.horizontal, 32)
                Spacer()
            }
            
            
        }
        .navigationBarBackButtonHidden(true)
        
    }
}
