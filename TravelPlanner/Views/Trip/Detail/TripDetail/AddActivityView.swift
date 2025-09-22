import SwiftUI

struct AddActivityView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var size
    @EnvironmentObject var navManager: NavigationManager
    @EnvironmentObject var activityViewModel: ActivityViewModel // Sử dụng ActivityViewModel từ environment
    let tripId: Int
    let tripDayId: Int
    @State private var activityName: String = ""
    @State private var address: String = ""
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var estimatedCost: Double = 0.0
    @State private var actualCost: Double? = nil
    @State private var note: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    init(tripId: Int, tripDayId: Int) {
        self.tripId = tripId
        self.tripDayId = tripDayId
        let calendar = Calendar.current
        let now = Date()
        let startHourMinute = calendar.dateComponents([.hour, .minute], from: now)
        let endHourMinute = calendar.dateComponents([.hour, .minute], from: now.addingTimeInterval(3600))
        
        self._startTime = State(initialValue: calendar.date(from: {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = startHourMinute.hour
            components.minute = startHourMinute.minute
            return components
        }()) ?? now)
        
        self._endTime = State(initialValue: calendar.date(from: {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = endHourMinute.hour
            components.minute = endHourMinute.minute
            return components
        }()) ?? now.addingTimeInterval(3600))
    }
    
    var body: some View {
        ZStack {
            Color.background
                .edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack {
                    headerView
                    formView
                    Spacer()
                }
                .frame(
                    maxWidth: size == .regular ? 600 : .infinity,
                    alignment: .center
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Lỗi"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .gesture(
            TapGesture()
                .onEnded { _ in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
    }
    
    private var headerView: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: { navManager.goBack() }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            Spacer()
            Text("Thêm hoạt động")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Spacer()
        }
        .ignoresSafeArea()
        .padding()
    }
    
    private var formView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("THÔNG TIN HOẠT ĐỘNG")
                .font(.system(size: 16))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 5)
            VStack(alignment: .leading) {
                Text("Tên hoạt động")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                CustomTextField(placeholder: "", text: $activityName, autocapitalization: .sentences, showIconImage: true,
                                imageName: "activity")
                .padding(.bottom, 10)
                
                Text("Địa điểm")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                CustomTextField(placeholder: "", text: $address, autocapitalization: .sentences, showIconImage: true,
                                imageName: "address", height: 80, isMultiline: true)
            }
            .padding(.horizontal)
            .padding(.bottom, 5)
            
            Divider()
                .frame(width: 1)
                .background(Color.Button)
            
            Text("THỜI GIAN")
                .font(.system(size: 16))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 5)
            VStack {
                datePicker(title: "Thời gian bắt đầu", date: $startTime)
                datePicker(title: "Thời gian kết thúc", date: $endTime)
            }
            .padding(.bottom, 5)
            .padding(.horizontal)
            
            Divider()
                .frame(width: 1)
                .background(Color.Button)
            
            Text("CHI PHÍ")
                .font(.system(size: 16))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 5)
            HStack {
                VStack(alignment: .leading) {
                    Text("Chi phí dự kiến")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    HStack {
                        CustomNumberTextField(value: $estimatedCost)
                        Text("đ")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                }
                Spacer()
                Divider()
                    .frame(width: 1)
                    .background(Color.Button)
                Spacer()
                VStack(alignment: .leading) {
                    Text("Chi phí thực tế")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    HStack {
                        CustomNumberTextField(value: Binding(
                            get: { actualCost ?? 0 },
                            set: { newValue in
                                actualCost = newValue == 0 ? nil : newValue
                            }
                        ))
                        Text("đ")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.bottom, 5)
            .padding(.horizontal)
            
            Divider()
            
            Text("GHI CHÚ")
                .font(.system(size: 16))
                .fontWeight(.bold)
                .foregroundColor(.white)
            CustomTextField(placeholder: "", text: $note, autocapitalization: .sentences, height: 80, isMultiline: true)
                .padding(.bottom, 20)
            
            addButton
        }
        .padding()
    }
    
    private func datePicker(title: String, date: Binding<Date>) -> some View {
        HStack(spacing: 4) {
            DatePicker(
                title,
                selection: date,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.compact)
            .foregroundColor(.white)
            .colorScheme(.dark)
            .environment(\.locale, Locale(identifier: "vi_VN"))
        }
    }
    
    private var addButton: some View {
        Button(action: addActivity) {
            Text("Thêm hoạt động")
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.Button)
                .cornerRadius(25)
        }
        .disabled(isSubmitting)
        .padding(.horizontal)
    }
    
    private func addActivity() {
        guard !activityName.isEmpty else {
            alertMessage = "Vui lòng nhập tên hoạt động"
            showAlert = true
            return
        }
        
        guard !address.isEmpty else {
            alertMessage = "Vui lòng nhập địa điểm"
            showAlert = true
            return
        }
        
        guard endTime > startTime else {
            alertMessage = "Thời gian kết thúc phải sau thời gian bắt đầu"
            showAlert = true
            return
        }
        
        guard estimatedCost >= 0 else {
            alertMessage = "Chi phí dự kiến không được âm"
            showAlert = true
            return
        }
        
        if let actualCostValue = actualCost, actualCostValue < 0 {
            alertMessage = "Chi phí thực tế không được âm"
            showAlert = true
            return
        }
        
        isSubmitting = true
        
        let newActivity = TripActivity(
            id: 0,
            tripDayId: tripDayId,
            startTime: Formatter.apiDateTimeFormatter.string(from: startTime),
            endTime: Formatter.apiDateTimeFormatter.string(from: endTime),
            activity: activityName,
            address: address,
            estimatedCost: estimatedCost,
            actualCost: actualCost,
            note: note,
            createdAt: "",
            updatedAt: "",
            activityImages: []
        )
        
        activityViewModel.addActivity(tripDayId: tripDayId, activity: newActivity) { result in
            DispatchQueue.main.async {
                isSubmitting = false
                switch result {
                case .success(let addedActivity):
                    activityName = ""
                    address = ""
                    estimatedCost = 0.0
                    actualCost = nil
                    note = ""
                    activityViewModel.showToast(message: "Đã thêm hoạt động: \(addedActivity.activity)", type: .success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.navManager.goBack()
                    }
                case .failure(let error):
                    print("❌ Lỗi khi thêm hoạt động: \(error.localizedDescription)")
                    activityViewModel.showToast(message: "Lỗi khi thêm hoạt động: \(error.localizedDescription)", type: .error)
                }
            }
        }
    }
}
