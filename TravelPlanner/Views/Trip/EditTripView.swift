import SwiftUI
import PhotosUI

struct EditTripView: View {
    @Environment(\.horizontalSizeClass) var size
    @EnvironmentObject private var tripViewModel: TripViewModel
    @EnvironmentObject var navManager: NavigationManager
    let trip: TripModel
    
    @StateObject private var imageViewModel = ImageViewModel()
    @State private var tripName: String
    @State private var tripDescription: String
    @State private var tripAddress: String
    @State private var tripStartDate: Date
    @State private var tripEndDate: Date
    @State private var showLocationSearch: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    @State private var selectedImage: UIImage? // Lưu ảnh được chọn
    @State private var selectedPhotoItem: PhotosPickerItem? // Cho PhotosPicker
    @State private var imageCoverData: Data? // Lưu dữ liệu ảnh
    @State private var isPublic: Bool = false
    @State private var isUpdating: Bool = false
    
    init(trip: TripModel) {
        self.trip = trip
        self._tripName = State(initialValue: trip.name)
        self._tripDescription = State(initialValue: trip.description ?? "")
        self._tripAddress = State(initialValue: trip.address ?? "")
        self._tripStartDate = State(initialValue: Formatter.apiDateFormatter.date(from: trip.startDate) ?? Date())
        self._tripEndDate = State(initialValue: Formatter.apiDateFormatter.date(from: trip.endDate) ?? Date())
        self._imageCoverData = State(initialValue: trip.imageCoverData)
        self._isPublic = State(initialValue: trip.isPublic)
        self._selectedImage = State(initialValue: trip.imageCoverData.flatMap { UIImage(data: $0) })
    }
    
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            ScrollView {
                headerView
                formView
                Spacer()
            }
            .frame(
                maxWidth: size == .regular ? 600 : .infinity,
                alignment: .center
            )
        }
        
        .navigationBarBackButtonHidden(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Lỗi"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onReceive(imageViewModel.$showToast) { show in
            if show, let message = imageViewModel.toastMessage, let type = imageViewModel.toastType {
                tripViewModel.showToast(message: message, type: type)
            }
        }
        .overlay {
                if isUpdating {
                    ZStack {
                        Color.black.opacity(0.4)                             .ignoresSafeArea()
                         LottieView(animationName: "loading2")
                             .frame(width: 50, height: 50)
                    }
                }
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
            Text("Chỉnh sửa chuyến đi")
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
                        } else if let url = trip.coverImageInfo?.url, !url.isEmpty {
                            AsyncImage(url: URL(string: url)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 150)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.Button, lineWidth: 2)
                                    )
                            } placeholder: {
                                ProgressView()
                            }
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
                .padding(.bottom)
                .onChange(of: selectedPhotoItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                            imageCoverData = data
                        } else {
                            showAlert = true
                            alertMessage = "Không thể tải ảnh được chọn"
                        }
                    }
                }
                
                Text("Hãy đặt tên cho chuyến đi của bạn")
                    .font(.system(size: 16, weight: .medium))
                CustomTextField(placeholder: "Tên chuyến đi", text: $tripName, autocapitalization: .sentences)
                    .padding(.bottom)
                
                Text("Địa điểm")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                Button(action: {
                    showLocationSearch = true
                }) {
                    HStack {
                        Text(tripAddress.isEmpty ? "Chọn địa điểm" : tripAddress)
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
                        initialLocation: tripAddress.isEmpty ? "Đà Lạt" : tripAddress,
                        selectedLocation: $tripAddress
                    )
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.clear)
                    .background(Color.background)
                    .ignoresSafeArea()
                }
                .padding(.bottom)
                
                Text("Hãy thêm mô tả cho chuyến đi của bạn")
                    .font(.system(size: 16, weight: .medium))
                CustomTextField(placeholder: "Mô tả (không bắt buộc)", text: $tripDescription, autocapitalization: .sentences, height: 80, isMultiline: true)
                    .padding(.bottom)
                Toggle(isOn: $isPublic) {
                    Text(isPublic ? "Công khai" : "Riêng tư")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.bottom)
                CustomDatePicker(title: "Ngày bắt đầu", date: $tripStartDate)
                    .padding(.bottom)
                CustomDatePicker(title: "Ngày kết thúc", date: $tripEndDate)
                    .padding(.bottom, 30)
                
                updateButton
            }
            .font(.system(size: 16))
            .foregroundColor(.white)
            .padding(10)
        }
        .padding(.horizontal)
    }
    
    private var updateButton: some View {
        Button(action: updateTrip) {
            Text("Cập nhật chuyến đi")
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.Button)
                .cornerRadius(25)
        }
        .disabled(imageViewModel.isLoading)
        .padding(.horizontal)
    }
    
    private func updateTrip() {
        guard !tripName.isEmpty else {
            alertMessage = "Vui lòng nhập tên chuyến đi"
            showAlert = true
            return
        }
        
        guard !tripAddress.isEmpty else {
            alertMessage = "Vui lòng nhập địa chỉ"
            showAlert = true
            return
        }
        
        guard tripEndDate >= tripStartDate else {
            alertMessage = "Ngày kết thúc phải sau hoặc bằng ngày bắt đầu"
            showAlert = true
            return
        }
        
        let start = Formatter.apiDateFormatter.string(from: tripStartDate)
        let end = Formatter.apiDateFormatter.string(from: tripEndDate)
        
        isUpdating = true
        
        tripViewModel.updateTrip(
            tripId: trip.id,
            name: tripName,
            description: tripDescription.isEmpty ? nil : tripDescription,
            startDate: start,
            endDate: end,
            address: tripAddress,
            imageCoverData: imageCoverData,
            isPublic: isPublic,
            completion: { success in
                        DispatchQueue.main.async {
                            isUpdating = false
                            if success {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("TripUpdated"),
                                    object: nil,
                                    userInfo: ["tripId": trip.id]
                                )
                                navManager.goBack()
                            } else {
                                alertMessage = "Cập nhật thất bại"
                                showAlert = true
                            }
                        }
                    }
        )
    }
}
