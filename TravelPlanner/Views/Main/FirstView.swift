import SwiftUI
struct FirstView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var navManager: NavigationManager
    var body: some View {
            ZStack {
                Color.background2.ignoresSafeArea(edges: .all)
                VStack {
                    Image(horizontalSizeClass == .regular ? "big" : "banner")
                        .resizable()
                        .ignoresSafeArea(edges: .all)
                        .frame(height: horizontalSizeClass == .regular ? 600 : 391)
                    Spacer()
                }
                VStack{
                    Spacer()
                    Image("logo")
                        .resizable()
                        .frame(width: horizontalSizeClass == .regular ? 187:87, height: horizontalSizeClass == .regular ? 211:111)
                        .padding(.bottom, 40)
                    Text("Đi đâu cũng được\nchỉ cần có Travel Planner.")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 24, weight: .bold, design: .default))
                        .foregroundColor(.white)
                    Spacer()
                    
                    VStack(spacing: 20){
                        Button {
                            navManager.go(to: .register)
                        } label: {
                            Text("Đăng kí miễn phí")
                                .font(.system(size: 18, weight: .bold, design: .default))
                                .foregroundColor(.white)
                                .frame(width: 275, height: 50)
                                .background(Color.Button)
                                .cornerRadius(25)
                            
                            
                        }
                        Button {
                            navManager.go(to: .signin)
                        } label: {
                            Text("Đăng nhập")
                                .font(.system(size: 18, weight: .bold, design: .default))
                                .foregroundColor(.white)
                                .frame(width: 275, height: 50)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.gray, lineWidth: 2)
                                )
                                .cornerRadius(25)
                        }
                    }
                    .padding(.bottom, 40)
                    
                }
                
                
            }
            
        }
        
    }

#Preview {
    RootView()
}
