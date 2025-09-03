import SwiftUI
import Photos
import WaterfallGrid

struct ActivityImagesView: View {
    @EnvironmentObject var navManager: NavigationManager
    let tripId: Int
    let tripDayId: Int
    let activityId: Int
    @StateObject private var viewModel = ActivityImagesViewModel()
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showPermissionAlert = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.background.ignoresSafeArea()
            VStack {
                // Header
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
                    Spacer()
                }
                .padding(.top, 15)
                .padding(.horizontal)
                
                // Content
                VStack {
                    if viewModel.isLoading && viewModel.images.isEmpty {
                        ProgressView("Đang tải danh sách...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if viewModel.images.isEmpty {
                        VStack(spacing: 10) {
                            Spacer()
                            Image("empty")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                            
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
                    } else {
                        ScrollView {
                            WaterfallGrid(viewModel.images, id: \.id) { image in
                                NavigationLink(
                                    destination: ActivityImagesWithUserView(
                                        image: image 
                                    )
                                ) {
                                    AsyncImage(url: URL(string: image.imageUrl ?? "")) { imagePhase in
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
                    
                    Spacer()
                    
                    Button(action: {
                        checkPhotoLibraryPermission()
                    }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                            Text("Tải hình ảnh lên")
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.Button)
                        .cornerRadius(25)
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.horizontal)
                }
                .padding(.top, 10)
                .task {
                    await prefetchInitialImages()
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(image: $selectedImage)
                }
                .onChange(of: selectedImage) { newImage in
                    print("📸 Selected image: \(newImage != nil ? "Valid image" : "nil")")
                    guard let image = newImage else {
                        print("❌ No image selected")
                        return
                    }
                    viewModel.uploadImage(tripId: tripId, tripDayId: tripDayId, activityId: activityId, image: image)
                }
                .alert(isPresented: $showPermissionAlert) {
                    Alert(
                        title: Text("Quyền truy cập thư viện ảnh"),
                        message: Text("Vui lòng cấp quyền truy cập thư viện ảnh trong Cài đặt để chọn ảnh"),
                        primaryButton: .default(Text("Mở Cài đặt")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
                .alert(isPresented: $viewModel.showToast) {
                    Alert(
                        title: Text("Thông báo"),
                        message: Text(viewModel.toastMessage ?? "Lỗi không xác định"),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ImageDeleted"))) { notification in
                            if let imageId = notification.userInfo?["imageId"] as? Int {
                                // Cập nhật danh sách ảnh bằng cách gọi lại fetchImages
                                viewModel.fetchImages(tripId: tripId, tripDayId: tripDayId, activityId: activityId)
                            }
                        }
            }
            if viewModel.isLoading && selectedImage != nil {
                ZStack{
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    LottieView(animationName: "loading2")
                        .frame(width: 100, height: 100)
                }
                
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private func prefetchInitialImages() async {
        viewModel.isLoading = true
        await viewModel.fetchImages(tripId: tripId, tripDayId: tripDayId, activityId: activityId)
        let initialCount = min(4, viewModel.images.count)
        if initialCount > 0 {
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<initialCount {
                    group.addTask {
                        if let url = URL(string: viewModel.images[i].imageUrl ?? "") {
                            _ = try? await URLSession.shared.data(from: url)
                        }
                    }
                }
            }
        }
        viewModel.isLoading = false
    }
    
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        print("📷 Photo library permission status: \(status.rawValue)")
        
        switch status {
        case .authorized, .limited:
            print("✅ Quyền truy cập được cấp, mở ImagePicker")
            DispatchQueue.main.async {
                self.showImagePicker = true
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    print("📷 New permission status: \(newStatus.rawValue)")
                    if newStatus == .authorized || newStatus == .limited {
                        self.showImagePicker = true
                    } else {
                        print("❌ Quyền bị từ chối: \(newStatus.rawValue)")
                        self.showPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            print("❌ Quyền truy cập bị từ chối hoặc bị hạn chế")
            DispatchQueue.main.async {
                self.showPermissionAlert = true
            }
        @unknown default:
            print("❌ Trạng thái quyền không xác định")
            DispatchQueue.main.async {
                self.showPermissionAlert = true
            }
        }
    }
}
