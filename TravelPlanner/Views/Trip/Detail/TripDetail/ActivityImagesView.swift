import SwiftUI
import WaterfallGrid
import PhotosUI

struct ActivityImagesView: View {
    let tripId: Int
    let tripDayId: Int
    let activityId: Int
    @StateObject private var viewModel = ActivityImagesViewModel()
    @EnvironmentObject var navManager: NavigationManager
    @EnvironmentObject var activityViewModel: ActivityViewModel
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.background.ignoresSafeArea()
            VStack {
                headerView
                contentView
            }
            .padding(.top, 15)
            .onAppear {
                print("📸 ActivityImagesView loaded with activityId: \(activityId)")
                viewModel.fetchImages(tripId: tripId, tripDayId: tripDayId, activityId: activityId)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private var headerView: some View {
        HStack {
            Button(action: {
                navManager.goBack()
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20))
                    Spacer()
                    Text("Ảnh của hoạt động")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 0,
                matching: .images
            ) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .onChange(of: selectedPhotos) { newPhotos in
                handlePhotoSelection(newPhotos)
            }
        }
        .padding(.horizontal)
    }
    
    private func handlePhotoSelection(_ photos: [PhotosPickerItem]) {
        guard !photos.isEmpty else { return }
        viewModel.isLoading = true
        var uiImages: [UIImage] = []
        let group = DispatchGroup()
        
        for photo in photos {
            group.enter()
            photo.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data, let uiImage = UIImage(data: data) {
                        uiImages.append(uiImage)
                    } else {
                        DispatchQueue.main.async {
                            self.activityViewModel.showToast(message: "Một hoặc nhiều hình ảnh không hợp lệ", type: .error)
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.activityViewModel.showToast(message: "Lỗi khi chọn ảnh: \(error.localizedDescription)", type: .error)
                    }
                }
                group.leave()
            }
        }
                
        group.notify(queue: .main) {
            if uiImages.isEmpty {
                self.activityViewModel.showToast(message: "Không có ảnh hợp lệ để tải lên", type: .error)
                self.viewModel.isLoading = false
                self.selectedPhotos = []
                return
            }
            
            // Gọi hàm uploadImages với danh sách ảnh
            self.viewModel.uploadImages(
                tripId: self.tripId,
                tripDayId: self.tripDayId,
                activityId: self.activityId,
                images: uiImages,
                activityViewModel: self.activityViewModel
            ) {
                print("✅ Hoàn tất tải và cập nhật ảnh")
                self.selectedPhotos = []
                self.viewModel.isLoading = false // Tắt hiệu ứng loading sau khi hoàn tất
            }
        }
    }
    
    private var contentView: some View {
        VStack {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.images.isEmpty {
                emptyView
            } else {
                imagesGridView
            }
            Spacer()
        }
    }
    
    private var loadingView: some View {
        ZStack {
            Color.black.opacity(0.0)                             .ignoresSafeArea()
             LottieView(animationName: "loading2")
                 .frame(width: 50, height: 50)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.gray.opacity(0.6))
            
            Text("Chưa có hình ảnh cho hoạt động này")
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Text("Hãy lưu giữ những khoảnh khắc quý giá bằng cách tải lên hình ảnh cho hoạt động này!")
                .foregroundColor(.gray)
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var imagesGridView: some View {
        ScrollView {
            if !viewModel.images.isEmpty {
                WaterfallGrid(viewModel.images, id: \.id) { image in
                    NavigationLink(
                        destination: ActivityImagesWithUserView(
                            image: image,
                            tripId: tripId,
                            tripDayId: tripDayId,
                            activityId: activityId
                        )
                    ) {
                        ImageItemView(image: image)
                    }
                }
                .gridStyle(
                    columns: 2,
                    spacing: 12,
                    animation: .default
                )
                .padding(.horizontal)
            } else {
                Text("Không có ảnh để hiển thị")
                    .foregroundColor(.white)
                    .font(.system(size: 14))
            }
        }
        .padding(.top, 10)
    }
}

struct ImageItemView: View {
    let image: ImageData
    
    var body: some View {
        if let url = URL(string: image.url), !image.url.isEmpty {
            AsyncImage(url: url) { imagePhase in
                switch imagePhase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(10)
                        .transition(.opacity)
                case .failure:
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
        }
    }
}
