import SwiftUI

struct EditTripView: View {
    @EnvironmentObject private var viewModel: TripViewModel
    @EnvironmentObject var navManager: NavigationManager
    let trip: TripModel // TripModel để hiển thị thông tin hiện tại
    
    @State private var tripName: String
    @State private var tripDescription: String
    @State private var tripAddress: String
    @State private var tripStartDate: Date
    @State private var tripEndDate: Date
    @State private var showLocationSearch: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    // Khởi tạo với giá trị từ TripModel
    init(trip: TripModel) {
        self.trip = trip
        self._tripName = State(initialValue: trip.name)
        self._tripDescription = State(initialValue: trip.description ?? "")
        self._tripAddress = State(initialValue: trip.address ?? "")
        // Chuyển đổi String thành Date
        self._tripStartDate = State(initialValue: Formatter.apiDateFormatter.date(from: trip.startDate) ?? Date())
        self._tripEndDate = State(initialValue: Formatter.apiDateFormatter.date(from: trip.endDate) ?? Date())
    }
    
    var body: some View {
        ScrollView {
            headerView
            formView
            Spacer()
        }
        .background(Color.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Lỗi"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
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
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(Color.pink)
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(Color.pink)
                }
                .padding(.bottom)
                
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
                        date: tripStartDate, // Bây giờ là Date
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
        .disabled(tripName.isEmpty || tripAddress.isEmpty || tripEndDate < tripStartDate)
        .padding(.horizontal)
    }
    
    // MARK: - Logic
    
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
        
        viewModel.updateTrip(
            tripId: trip.id,
            name: tripName,
            description: tripDescription.isEmpty ? nil : tripDescription,
            startDate: start,
            endDate: end,
            address: tripAddress,
            imageCoverUrl: trip.imageCoverUrl,
            imageCoverData: trip.imageCoverData // Giữ nguyên imageCoverUrl từ trip ban đầu
        ) { success in
            if success {
                navManager.goBack()
            } else {
                alertMessage = "Cập nhật thất bại"
                showAlert = true
            }
        }
    }
}
