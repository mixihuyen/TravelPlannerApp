import SwiftUI

struct EditActivityView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var navManager: NavigationManager
    let selectedDate: Date
    let trip: TripModel
    let activity: TripActivity
    @EnvironmentObject var viewModel: TripDetailViewModel
    @State private var activityName: String
    @State private var address: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var estimatedCost: Double
    @State private var actualCost: Double
    @State private var note: String
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    
    init(selectedDate: Date, trip: TripModel, activity: TripActivity) {
        self.selectedDate = selectedDate
        self.trip = trip
        self.activity = activity
        self._activityName = State(initialValue: activity.activity)
        self._address = State(initialValue: activity.address)
        self._startTime = State(initialValue: Formatter.apiDateTimeFormatter.date(from: activity.startTime) ?? selectedDate)
        self._endTime = State(initialValue: Formatter.apiDateTimeFormatter.date(from: activity.endTime) ?? selectedDate.addingTimeInterval(3600))
        self._estimatedCost = State(initialValue: activity.estimatedCost)
        self._actualCost = State(initialValue: activity.actualCost)
        self._note = State(initialValue: activity.note)
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
            Text("Chỉnh sửa hoạt động")
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
            VStack(alignment: .leading){
                Text("Tên hoạt động")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                CustomTextField(placeholder: "", text: $activityName, autocapitalization: .sentences, showIconImage: true, imageName: "activity")
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
            VStack{
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
            HStack{
                VStack(alignment: .leading){
                    Text("Chi phí dự kiến")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    HStack{
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
                VStack(alignment: .leading){
                    Text("Chi phí thực tế")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    HStack{
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
            
            updateButton
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
    
    private var updateButton: some View {
        Button(action: updateActivity) {
            Text("Cập nhật hoạt động")
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.Button)
                .cornerRadius(25)
        }
        .disabled(activityName.isEmpty)
        .padding(.horizontal)
    }
    
    private func updateActivity() {
            guard !activityName.isEmpty else {
                return
            }
            
            let updatedActivity = TripActivity(
                id: activity.id,
                tripDayId: activity.tripDayId,
                startTime: Formatter.apiDateTimeFormatter.string(from: startTime),
                endTime: Formatter.apiDateTimeFormatter.string(from: endTime),
                activity: activityName,
                address: address,
                estimatedCost: estimatedCost,
                actualCost: actualCost,
                note: note,
                createdAt: activity.createdAt,
                updatedAt: activity.updatedAt
            )
            
            viewModel.updateActivity(trip: trip, date: selectedDate, activity: updatedActivity) { result in
                switch result {
                case .success(let updatedActivity):
                    print("✅ Đã cập nhật hoạt động: \(updatedActivity.activity)")
                    DispatchQueue.main.async {
                        self.showToast = true
                        self.toastMessage = "Cập nhật hoạt động thành công"
                        print("📢 Đặt toast trong EditActivityView: \(self.toastMessage)")
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.showToast = false
                        self.toastMessage = ""
                        print("📢 Ẩn toast trong EditActivityView")
                        self.navManager.goBack()
                    }
                case .failure(let error):
                    print("❌ Lỗi khi cập nhật hoạt động: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.showToast = true
                        self.toastMessage = "Lỗi khi cập nhật hoạt động"
                        print("📢 Đặt toast trong EditActivityView: \(self.toastMessage)")
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.showToast = false
                        self.toastMessage = ""
                        print("📢 Ẩn toast trong EditActivityView")
                        self.navManager.goBack()
                    }
                }
            }
        }
    }
