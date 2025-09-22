import SwiftUI
import WaterfallGrid

struct ProfileView: View {
    @State private var showSidebar = false
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var navManager: NavigationManager
    @EnvironmentObject var imageViewModel: ImageViewModel 

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            ScrollView {
                VStack {
                    HStack(alignment: .top) {
                        Image("noti")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Spacer()
                        VStack {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(authManager.avatarInitials())
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                )
                            Text(authManager.currentUserName ?? "Name")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            let username = authManager.username ?? "username"
                            Text("@\(username)")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 50)
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
                    WaterfallGrid(imageViewModel.images, id: \.id) { item in
                        AsyncImage(url: URL(string: item.url)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 100, height: 100)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(10)
                            case .failure:
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.red)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                            @unknown default:
                                EmptyView()
                            }
                        }
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
        .onAppear {
            imageViewModel.fetchImagesOfUsers() // Gọi fetch khi view xuất hiện
        }
    }
}
