import SwiftUI
import WaterfallGrid
struct ProfileView: View {
    @State private var showSidebar = false
    let images = TripViewModel.sampleImage
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var navManager: NavigationManager
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            ScrollView{
                VStack{
                    HStack (alignment: .top) {
                        Image("noti")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Spacer()
                        VStack{
                            Image("profile")
                                .resizable()
                                .background(Color.gray.opacity(0.2))
                                .frame(width: 130, height: 130)
                                .clipShape(Circle())
                                .padding()
                            Text(authManager.currentUserName ?? "Name")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            let username = authManager.username ?? "username"
                            Text("@\(username)" ?? "username")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            
                        }
                        Spacer()
                        
                        
                        Button(action: {
                            withAnimation {
                                showSidebar.toggle()
                            }
                        }) {
                            Image("setting")
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                    WaterfallGrid(images, id: \.id) { item in
                        Image(item.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(10)
                    }
                    .gridStyle(
                        columns: 2,
                        spacing: 12,
                        animation: .default
                    )
                    .padding(.horizontal)
                    
                    
                }
            }
            if showSidebar {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showSidebar = false
                        }
                    }
                
                HStack {
                    Spacer()
                    SideBar {
                        authManager.setNavigationManager(navManager)
                        authManager.logout()
                        
                        print("Đăng xuất")
                        showSidebar = false
                    }
                }
                .transition(.move(edge: .trailing))
            }
            
        }
    }
}
#Preview {
    ProfileView()
}
