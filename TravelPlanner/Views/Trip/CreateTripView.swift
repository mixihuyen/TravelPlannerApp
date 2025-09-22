import SwiftUI
import PhotosUI
import Photos

struct CreateTripView: View {
    @Environment(\.horizontalSizeClass) var size
    @EnvironmentObject private var viewModel: TripViewModel
    @EnvironmentObject var navManager: NavigationManager
    
    @StateObject private var imageViewModel = ImageViewModel()
    @State private var newTripName: String = ""
    @State private var newTripDescription: String = ""
    @State private var newTripAddress: String = ""
    @State private var newTripStartDate = Date()
    @State private var newTripEndDate = Date()
    @State private var showLocationSearch: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageCoverData: Data?
    @State private var coverImageId: Int?
    @State private var isPublic: Bool = false
    @State private var photoPermissionStatus: PHAuthorizationStatus = .notDetermined
    @State private var isTripCreated: Bool = false
    

    var body: some View {
        ZStack{
            Color.background
                .ignoresSafeArea()
            ScrollView {
                VStack {
                    headerView
                    formView
                }
                
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Lỗi"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                }
                
            }
            .frame(
                maxWidth: size == .regular ? 600 : .infinity,
                alignment: .center
            )
        }
        .navigationBarBackButtonHidden(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(imageViewModel.$showToast) { show in
            if show, let message = imageViewModel.toastMessage, let type = imageViewModel.toastType {
                viewModel.showToast(message: message, type: type)
            }
        }
        .onAppear {
            checkPhotoPermission()
        }
    }
    
    private var headerView: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: { navManager.goBack() }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            Spacer()
            Text("Tạo chuyến đi mới")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Spacer()
        }
        .ignoresSafeArea()
        .padding()
    }
    
    private var formView: some View {
        VStack(alignment: .leading) {
            Text("THÔNG TIN CHUYẾN ĐI")
                .font(.system(size: 16))
                .fontWeight(.bold)
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 7) {
                Text("Ảnh bìa")
                    .font(.system(size: 16, weight: .medium))
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(Color.pink)
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 150)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.Button, lineWidth: 2)
                                )
                        } else {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(Color.pink)
                        }
                        if imageViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.5)
                        }
                    }
                }
                .disabled(photoPermissionStatus != .authorized || isTripCreated) // Vô hiệu hóa sau khi tạo chuyến đi
                .padding(.bottom)
                .onChange(of: selectedPhotoItem) { newItem in
                    guard !isTripCreated else {
                        print("🚫 Bỏ qua onChange vì chuyến đi đã được tạo")
                        return
                    }
                    Task {
                        print("📸 Bắt đầu xử lý selectedPhotoItem: \(String(describing: newItem))")
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                            imageCoverData = data
                            print("📸 Load ảnh thành công, kích thước: \(data.count) bytes")
                            imageViewModel.uploadImage(data) { result in
                                switch result {
                                case .success(let imageInfo):
                                    coverImageId = imageInfo.id
                                    print("📸 Ảnh được tải lên thành công, ID: \(imageInfo.id)")
                                    viewModel.showToast(message: "Ảnh bìa được tải lên thành công!", type: .success)
                                case .failure(let error):
                                    print("❌ Lỗi tải ảnh lên: \(error.localizedDescription)")
                                    showAlert = true
                                    alertMessage = "Không thể tải ảnh lên: \(error.localizedDescription)"
                                    coverImageId = nil
                                    imageCoverData = nil
                                    selectedImage = nil
                                    selectedPhotoItem = nil
                                }
                            }
                        } else {
                            print("❌ Không thể load dữ liệu ảnh từ PhotosPickerItem")
                            showAlert = true
                            alertMessage = "Không thể tải ảnh được chọn. Vui lòng kiểm tra quyền truy cập thư viện ảnh hoặc thử ảnh khác."
                            coverImageId = nil
                            imageCoverData = nil
                            selectedImage = nil
                            selectedPhotoItem = nil
                        }
                    }
                }
                
                if photoPermissionStatus != .authorized {
                    Text("Vui lòng cấp quyền truy cập thư viện ảnh để chọn ảnh bìa")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.bottom)
                    Button("Mở Cài đặt") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                
                Text("Hãy đặt tên cho chuyến đi của bạn")
                    .font(.system(size: 16, weight: .medium))
                CustomTextField(placeholder: "Tên chuyến đi", text: $newTripName, autocapitalization: .sentences)
                    .padding(.bottom)
                
                Text("Địa điểm")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                Button(action: {
                    showLocationSearch = true
                }) {
                    HStack {
                        Text(newTripAddress.isEmpty ? "Chọn địa điểm" : newTripAddress)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.Button)
                    )
                }
                .sheet(isPresented: $showLocationSearch) {
                    LocationSearchView(
                        initialLocation: newTripAddress.isEmpty ? "Đà Lạt" : newTripAddress,
                        selectedLocation: $newTripAddress
                    )
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.clear)
                    .background(Color.background)
                    .ignoresSafeArea()
                }
                .padding(.bottom)
                
                Text("Hãy thêm mô tả cho chuyến đi của bạn")
                    .font(.system(size: 16, weight: .medium))
                CustomTextField(placeholder: "Mô tả (không bắt buộc)", text: $newTripDescription, autocapitalization: .sentences, height: 80, isMultiline: true)
                    .padding(.bottom)
                Toggle(isOn: $isPublic) {
                    Text(isPublic ? "Công khai" : "Riêng tư")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.bottom)
                
                CustomDatePicker(title: "Ngày bắt đầu", date: $newTripStartDate)
                    .padding(.bottom)
                CustomDatePicker(title: "Ngày kết thúc", date: $newTripEndDate)
                    .padding(.bottom, 30)
                
                addButton
            }
            .font(.system(size: 16))
            .foregroundColor(.white)
            .padding(10)
        }
        .padding(.horizontal)
    }
    
    private var addButton: some View {
        Button(action: addTrip) {
            Text("Thêm chuyến đi")
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.Button)
                .cornerRadius(25)
        }
        .disabled(imageViewModel.isLoading)
        .padding(.horizontal)
    }
    
    private func addTrip() {
        guard !newTripName.isEmpty else {
            alertMessage = "Vui lòng nhập tên chuyến đi"
            showAlert = true
            return
        }
        
        guard !newTripAddress.isEmpty else {
            alertMessage = "Vui lòng nhập địa chỉ"
            showAlert = true
            return
        }
        
        guard newTripEndDate >= newTripStartDate else {
            alertMessage = "Ngày kết thúc phải sau hoặc bằng ngày bắt đầu"
            showAlert = true
            return
        }
        
        // Chỉ kiểm tra coverImageId nếu đã chọn ảnh và upload chưa thành công
        if selectedPhotoItem != nil && coverImageId == nil && !imageViewModel.isLoading {
            alertMessage = "Ảnh bìa chưa được tải lên thành công. Vui lòng chờ hoặc thử lại."
            showAlert = true
            return
        }
        
        let start = Formatter.apiDateFormatter.string(from: newTripStartDate)
        let end = Formatter.apiDateFormatter.string(from: newTripEndDate)
        
        print("🚀 Bắt đầu tạo chuyến đi với coverImageId: \(String(describing: coverImageId)), imageCoverData: \(imageCoverData?.count ?? 0) bytes")
        
        viewModel.addTrip(
            name: newTripName,
            description: newTripDescription.isEmpty ? "" : newTripDescription,
            startDate: start,
            endDate: end,
            address: newTripAddress,
            coverImage: coverImageId,
            imageCoverData: imageCoverData,
            isPublic: isPublic
        )
        
        isTripCreated = true // Đánh dấu chuyến đi đã được tạo
        resetForm()
        
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            navManager.goBack()
        }
    }
    
    private func resetForm() {
        newTripName = ""
        newTripDescription = ""
        newTripAddress = ""
        newTripStartDate = Date()
        newTripEndDate = Date()
        selectedImage = nil
        selectedPhotoItem = nil
        imageCoverData = nil
        coverImageId = nil
        isPublic = false
        print("🗑️ Form đã được reset")
    }
    
    private func checkPhotoPermission() {
        photoPermissionStatus = PHPhotoLibrary.authorizationStatus()
        if photoPermissionStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.photoPermissionStatus = status
                    if status != .authorized {
                        self.showAlert = true
                        self.alertMessage = "Ứng dụng cần quyền truy cập thư viện ảnh để chọn ảnh bìa. Vui lòng cấp quyền trong Cài đặt."
                    }
                }
            }
        } else if photoPermissionStatus != .authorized {
            showAlert = true
            alertMessage = "Ứng dụng cần quyền truy cập thư viện ảnh để chọn ảnh bìa. Vui lòng cấp quyền trong Cài đặt."
        }
    }
}
