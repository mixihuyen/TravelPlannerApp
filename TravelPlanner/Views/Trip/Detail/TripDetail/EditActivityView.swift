import SwiftUI

struct EditActivityView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var navManager: NavigationManager
    let selectedDate: Date
    let trip: TripModel
    let activity: TripActivity
    let tripDayId: Int
    @EnvironmentObject var viewModel: TripDetailViewModel
    @State private var activityName: String
    @State private var address: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var estimatedCost: Double
    @State private var actualCost: Double
    @State private var note: String
    @State private var showDeleteAlert = false
    @State private var isSubmitting: Bool = false
    
    init(selectedDate: Date, trip: TripModel, activity: TripActivity, tripDayId: Int) {
        self.selectedDate = selectedDate
        self.trip = trip
        self.activity = activity
        self.tripDayId = tripDayId
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
        .alert("Xoá hoạt động?", isPresented: $showDeleteAlert) {
            Button("Xoá", role: .destructive, action: deleteActivity)
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Bạn có chắc chắn muốn xoá hoạt động này?")
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
            VStack(alignment: .leading) {
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
            
            updateButton
            Button(role: .destructive, action: {
                showDeleteAlert = true
            }) {
                Text("Xoá hoạt động")
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(25)
            }
            .padding(.horizontal)
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
        .disabled(isSubmitting || activityName.isEmpty || endTime <= startTime)
        .padding(.horizontal)
    }
    
    private func updateActivity() {
        guard !activityName.isEmpty else {
            viewModel.showToast(message: "Vui lòng nhập tên hoạt động")
            return
        }
        
        guard endTime > startTime else {
            viewModel.showToast(message: "Thời gian kết thúc phải sau thời gian bắt đầu")
            return
        }
        
        guard estimatedCost >= 0, actualCost >= 0 else {
            viewModel.showToast(message: "Chi phí không được âm")
            return
        }
        
        isSubmitting = true
        
        let updatedActivity = TripActivity(
            id: activity.id,
            tripDayId: tripDayId,
            startTime: Formatter.apiDateTimeFormatter.string(from: startTime),
            endTime: Formatter.apiDateTimeFormatter.string(from: endTime),
            activity: activityName,
            address: address,
            estimatedCost: estimatedCost,
            actualCost: actualCost,
            note: note,
            createdAt: activity.createdAt,
            updatedAt: activity.updatedAt,
            images: activity.images ?? []
        )
        
        viewModel.updateActivity(trip: trip, date: selectedDate, activity: updatedActivity) { result in
            DispatchQueue.main.async {
                isSubmitting = false
                switch result {
                case .success(let updatedActivity):
                    print("✅ Đã cập nhật hoạt động: \(updatedActivity.activity)")
                    viewModel.showToast(message: "Đã cập nhật hoạt động: \(updatedActivity.activity)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.navManager.goBack()
                    }
                case .failure(let error):
                    print("❌ Lỗi khi cập nhật hoạt động: \(error.localizedDescription)")
                    viewModel.showToast(message: "Lỗi khi cập nhật hoạt động: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func deleteActivity() {
        isSubmitting = true
        viewModel.deleteActivity(activityId: activity.id, tripDayId: tripDayId) {
            DispatchQueue.main.async {
                isSubmitting = false
                print("📋 Đã xóa hoạt động và làm mới danh sách")
                viewModel.showToast(message: "Đã xóa hoạt động")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.navManager.goBack()
                }
            }
        }
    }
}
