import SwiftUI

struct CreateTripView: View {
    @EnvironmentObject private var viewModel : TripViewModel
    @EnvironmentObject var navManager: NavigationManager
    
    @State private var newTripName: String = ""
    @State private var newTripDescription: String = ""
    @State private var newTripAddress: String = ""
    @State private var newTripStartDate = Date()
    @State private var newTripEndDate = Date()
    @State private var showLocationSearch: Bool = false
    
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        ScrollView {
            headerView
            formView
            Spacer()
        }
        .background(Color.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var headerView: some View {
            HStack (alignment: .center, spacing: 0)  {
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
            VStack (alignment: .leading, spacing: 7){
                Text("Ảnh bìa")
                    .font(.system(size: 16, weight: .medium))
                ZStack{
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
                CustomTextField(placeholder: "Tên chuyến đi", text: $newTripName, autocapitalization: .sentences)
                    .padding(.bottom)
                
                
                // Chọn địa điểm
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
                                        date: newTripStartDate, // Sử dụng start date cho tìm kiếm
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
        .disabled(newTripName.isEmpty)
        .padding(.horizontal)
    }
    

    // MARK: - Logic
    
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
        
        let start = Formatter.apiDateFormatter.string(from: newTripStartDate)
        let end = Formatter.apiDateFormatter.string(from: newTripEndDate)
        
        viewModel.addTrip(
            name: newTripName,
            description: newTripDescription.isEmpty ? nil : newTripDescription,
            startDate: start,
            endDate: end,
            address: newTripAddress
        )
        
        resetForm()
        
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            navManager.goToRoot()
        }
    }
    
    private func resetForm() {
        newTripName = ""
        newTripDescription = ""
        newTripAddress = ""
        newTripStartDate = Date()
        newTripEndDate = Date()
        
    }
}
