import SwiftUI

struct AddActivityView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var navManager: NavigationManager
    let selectedDate: Date
    let trip: TripModel
    let tripDayId: Int
    @EnvironmentObject var viewModel: TripDetailViewModel
    @State private var activityName: String = ""
    @State private var address: String = ""
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var estimatedCost: Double = 0.0
    @State private var actualCost: Double = 0.0
    @State private var note: String = ""
    
    init(selectedDate: Date, trip: TripModel, tripDayId: Int) {
        self.selectedDate = selectedDate
        self.trip = trip
        self.tripDayId = tripDayId
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let startHourMinute = calendar.dateComponents([.hour, .minute], from: Date())
        let endHourMinute = calendar.dateComponents([.hour, .minute], from: Date().addingTimeInterval(3600))
        
        self._startTime = State(initialValue: calendar.date(from: {
            var components = dateComponents
            components.hour = startHourMinute.hour
            components.minute = startHourMinute.minute
            return components
        }()) ?? selectedDate)
        
        self._endTime = State(initialValue: calendar.date(from: {
            var components = dateComponents
            components.hour = endHourMinute.hour
            components.minute = endHourMinute.minute
            return components
        }()) ?? selectedDate.addingTimeInterval(3600))
    }
    
    var body: some View {
        ScrollView {
            VStack {
                headerView
                formView
                Spacer()
            }
        }
        .background(Color.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Text("THÔNG TIN CHUYẾN ĐI")
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
                        CustomNumberTextField(value: $actualCost)
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
        .disabled(activityName.isEmpty)
        .padding(.horizontal)
    }
    
    private func addActivity() {
        guard !activityName.isEmpty else {
            viewModel.showToast(message: "Vui lòng nhập tên hoạt động")
            return
        }
        
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
            images:  []
        )
        viewModel.clearCache()
        
        viewModel.addActivity(trip: trip, date: selectedDate, activity: newActivity) { result in
            switch result {
            case .success(let addedActivity):
                print("✅ Đã thêm hoạt động: \(addedActivity.activity)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.navManager.goBack()
                }
            case .failure(let error):
                print("❌ Lỗi khi thêm hoạt động: \(error.localizedDescription)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.navManager.goBack()
                }
            }
        }
    }
}
