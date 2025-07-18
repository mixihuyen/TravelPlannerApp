import SwiftUI
struct CreateTripPopup: View {
    @State private var firstname: String = ""
    @State private var lastname: String = ""
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
            VStack (spacing: 20) {
                Text("Tên của bạn là gì?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                CustomTextField(placeholder: "Họ", text: $firstname)
                    .autocapitalization(.words)
                
                CustomTextField(placeholder: "Tên", text: $lastname)
                    .autocapitalization(.words)
                Button(action: {
                    navManager.go(to: .usernameView)
                }) {
                    Text("Tiếp")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold))
                        .frame(maxWidth: 100)
                        .frame(height: 50)
                        .background(
                            Color.Button
                        )
                        .cornerRadius(25)
                }
                .padding(.top, 32)
            }
            .padding(.horizontal, 32)
            
        }
        .navigationBarBackButtonHidden(true)
    }
}
#Preview {
    NameView()
}
