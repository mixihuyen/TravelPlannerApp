import SwiftUI

struct HomeView: View {
    @Environment(\.horizontalSizeClass) var size
    @EnvironmentObject var imageViewModel: ImageViewModel
    @State private var retryTriggers: [Int: Bool] = [:]
    
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            
            VStack{
                ZStack(alignment: .center) {
                    Rectangle()
                        .fill(Color.background2)
                        .ignoresSafeArea(edges: .all)
                        .frame(height: 70)
                    Text("Bảng tin")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(height: 35)
                .frame(maxWidth: .infinity)
                ZStack{
                    
                    let _ = print("🖼️ Body rendering: isLoading=\(imageViewModel.isLoading), images.count=\(imageViewModel.publicImages.count)")
                    if imageViewModel.isLoading  && imageViewModel.publicImages.isEmpty{
                        LottieView(animationName: "loading2")
                            .frame(width: 50, height: 50)
                    } else
                    if  imageViewModel.publicImages.isEmpty {
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
                    } else
                    {

                        
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(imageViewModel.publicImages) { item in
                                    VStack(spacing: 8) {
                                        ImageContentView(
                                            item: item,
                                            size: size,
                                            retryTrigger: retryTriggers[item.id, default: false],
                                            onRetry: { retryTriggers[item.id, default: false].toggle() }
                                        )
                                        
                                        if let user = item.createdByUser {
                                            HStack(spacing: 10) {
                                                Circle()
                                                    .fill(Color.pink)
                                                    .frame(width: 35, height: 35)
                                                    .overlay(
                                                        Text(avatarInitials(for: user))
                                                            .font(.system(size: 15, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )
                                                Text(user.username ?? "Không xác định")
                                                    .font(.system(size: 18, weight: .medium))
                                                    .foregroundColor(.white)
                                                Spacer()
                                            }
                                            .padding(.horizontal)
                                            .padding(.top, 8)
                                            .frame(maxWidth: size == .regular ? 600 : .infinity)
                                        } else {
                                            Text("Không có thông tin người dùng")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(.gray)
                                                .padding(.horizontal)
                                                .padding(.top, 8)
                                                .frame(maxWidth: size == .regular ? 600 : .infinity)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .id(item.id)
                                    .transition(.opacity.combined(with: .slide))
                                    .onAppear {
                                        if item.id == imageViewModel.publicImages.last?.id && !imageViewModel.isLoading {
                                            print("🚀 Load more triggered for item \(item.id), publicImages.count: \(imageViewModel.publicImages.count)")
                                            imageViewModel.loadMoreImages(isPublic: true)
                                        }
                                    }
                                }
                                
                                if imageViewModel.isLoading  && !imageViewModel.publicImages.isEmpty   {
                                    VStack(spacing: 8) {
                                        ProgressView()
                                            .frame(width: 50, height: 50)
                                    }
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .refreshable {
                            print("🚀 Refresh triggered")
                            imageViewModel.refreshImages(isPublic: true)
                        }
                    }
                    
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    
                
                
            }
            
        }
        .onAppear {
                        print("🚀 HomeView onAppear: Gọi fetchPublicImages")
                        imageViewModel.fetchPublicImages()

                }
    }
    
    private func avatarInitials(for user: UserInformation) -> String {
        let firstInitial = user.firstName?.prefix(1) ?? ""
        let lastInitial = user.lastName?.prefix(1) ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
}

// Sub-view để xử lý hiển thị ảnh
struct ImageContentView: View {
    let item: ImageData
    let size: UserInterfaceSizeClass?
    let retryTrigger: Bool
    let onRetry: () -> Void
    
    var body: some View {
        Group {
            let _ = print("🔍 ImageContentView: imageId=\(item.id), createdByUser=\(item.createdByUser?.username ?? "nil")")
            if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: size == .regular ? 600 : .infinity)
                    .clipped()
            } else {
                AsyncImage(
                    url: URL(string: item.url),
                    transaction: Transaction(animation: .easeInOut)
                ) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 100, height: 100)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: size == .regular ? 600 : .infinity)
                            .clipped()
                    case .failure:
                        Button(action: onRetry) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: size == .regular ? 600 : .infinity)
                                .frame(height: 400)
                                .background(Color.gray.opacity(0.2))
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .id("\(item.id)-\(retryTrigger)")
            }
        }
        .frame(maxWidth: size == .regular ? 600 : .infinity)
    }
}
