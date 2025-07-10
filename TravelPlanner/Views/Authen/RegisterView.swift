
import SwiftUI
struct RegisterView : View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Binding var path: NavigationPath
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
                path.removeLast(path.count)
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
                VStack {
                    Spacer()
                    Text("Get Started Free")
                        .font(.system(size: horizontalSizeClass == .regular ? 68 : 36))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Đăng kí để bắt đầu lên kế hoạch")
                        .font(.system(size: horizontalSizeClass == .regular ? 28 : 15))
                        .foregroundColor(.white)
                        .padding(.bottom, horizontalSizeClass == .regular ? 38 : 0)
                    VStack(spacing: 16) {
                        LoginButton(icon: "envelope.fill", text: "Tiếp tục email")
                        LoginButton(icon: "phone.fill", text: "Tiếp tục bằng số điện thoại")
                        LoginButton(icon: "logo-facebook", text: "Tiếp tục với Facebook")
                        LoginButton(icon: "apple.logo", text: "Tiếp tục với Apple")
                        LoginButton(icon: "logo-google", text: "Tiếp tục với Google")
                    }
                    .padding(.top ,32)
                    VStack{
                        Text("Bạn đã có tài khoản?")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                        Button {
                            path.append(Route.signin)
                        } label: {
                            Text("Đăng nhập")
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
#Preview {
    RegisterView(path: .constant(NavigationPath()))
}

