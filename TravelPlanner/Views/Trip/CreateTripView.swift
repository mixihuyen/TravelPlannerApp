import SwiftUI

struct CreateTripView: View {
    @EnvironmentObject private var viewModel : TripViewModel
    @EnvironmentObject var navManager: NavigationManager
    
    @State private var newTripName: String = ""
    @State private var newTripDescription: String = ""
    @State private var newTripAddress: String = ""
    @State private var newTripStartDate = Date()
    @State private var newTripEndDate = Date()
    
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        VStack {
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
        VStack(alignment: .leading, spacing: 14) {
            Group {
                Text("Hãy đặt tên cho chuyến đi của bạn")
                CustomTextField(placeholder: "Tên chuyến đi", text: $newTripName, autocapitalization: .sentences)
                
                Text("Hãy thêm mô tả cho chuyến đi của bạn")
                CustomTextField(placeholder: "Mô tả (không bắt buộc)", text: $newTripDescription, autocapitalization: .sentences)
                Text("Hãy nhập địa chỉ cho chuyến đi")
                            CustomTextField(placeholder: "Địa chỉ", text: $newTripAddress, autocapitalization: .sentences)
            }
            .font(.system(size: 16))
            .foregroundColor(.white)
            
            datePicker(title: "Ngày bắt đầu", date: $newTripStartDate)
            datePicker(title: "Ngày kết thúc", date: $newTripEndDate)
            
            addButton
        }
        .padding()
    }
    
    private func datePicker(title: String, date: Binding<Date>) -> some View {
        DatePicker(title, selection: date, displayedComponents: .date)
            .datePickerStyle(.compact)
            .foregroundColor(.white)
            .colorScheme(.dark)
            .environment(\.locale, Locale(identifier: "vi_VN"))
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
