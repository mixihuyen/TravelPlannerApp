import SwiftUI
import WaterfallGrid

struct ProfileView: View {
    @State private var showSidebar = false
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var navManager: NavigationManager
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var imageViewModel: ImageViewModel
    @Environment(\.horizontalSizeClass) var size
    @State private var retryTriggers: [Int: Bool] = [:]
    @State private var shouldShowEmptyState: Bool = false
    
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
                                .fill(Color.pink)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(profileViewModel.avatarInitials())
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                )
                            Text(profileViewModel.userFullName() ?? authManager.currentUserName ?? "Khách")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            Text("@\(profileViewModel.userInfo?.username ?? authManager.username ?? "username")")
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
                    
                    VStack{
                        if imageViewModel.isLoading && imageViewModel.userImages.isEmpty  {
                            VStack {
                                LottieView(animationName: "loading2")
                                    .frame(width: 50, height: 50)
                            }
                            .padding(.top, 100)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else
                        if imageViewModel.userImages.isEmpty{
                            VStack(spacing: 10) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.gray.opacity(0.6))
                                
                                Text("Không có ảnh nào để hiển thị")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 100)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        else {
                            WaterfallGrid(imageViewModel.userImages, id: \.id) { item in
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
                                            .onAppear {
                                                if item.id == imageViewModel.userImages.last?.id {
                                                    imageViewModel.loadMoreImages(isPublic: false)
                                                }
                                            }
                                    case .failure:
                                        Button(action: {
                                                imageViewModel.refreshImages(isPublic: false)
                                            }) {
                                                VStack {
                                                    Image(systemName: "arrow.clockwise")
                                                        .font(.system(size: 24, weight: .medium))
                                                        .foregroundColor(.white)
                                                    Text("Thử lại")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.white)
                                                }
                                                .frame(maxWidth: size == .regular ? 600 : .infinity)
                                                .frame(height: 200)
                                                .background(Color.gray.opacity(0.2))
                                                .cornerRadius(10)
                                            }
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    
                    
                    if imageViewModel.isLoading && !imageViewModel.userImages.isEmpty {
                        ProgressView()
                            .padding()
                    }
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
        .overlay(
            Group {
                if imageViewModel.showToast, let message = imageViewModel.toastMessage, let type = imageViewModel.toastType {
                    ToastView(message: message, type: type)
                }
            },
            alignment: .bottom
        )
        .onAppear {
            if imageViewModel.userImages.isEmpty && !imageViewModel.isLoading {
                print("🚀 ProfileView onAppear: Gọi fetchImagesOfUsers")
                imageViewModel.fetchImagesOfUsers()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.shouldShowEmptyState = true
                }
            }
            if profileViewModel.userInfo == nil && !profileViewModel.isLoading {
                print("🚀 ProfileView onAppear: Gọi fetchUserProfile")
                profileViewModel.fetchUserProfile()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserProfileUpdated"))) { _ in
            print("🚀 Nhận thông báo UserProfileUpdated, gọi fetchUserProfile")
            profileViewModel.fetchUserProfile()
        }
        .animation(.easeInOut(duration: 0.3), value: imageViewModel.userImages)
    }
}

