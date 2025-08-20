import Foundation
import Combine
import SwiftUI
import Network
import CoreData

enum PendingActionType: String, Codable {
    case add
    case update
}

struct PendingActivity: Codable {
    let action: PendingActionType
    let activity: TripActivity
    let date: Date
}

class TripDetailViewModel: ObservableObject {
    let trip: TripModel
    @Published var tripDays: [Date] = []
    @Published var tripDaysData: [TripDay] = []
    @Published var isLoading: Bool = false
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    @Published var refreshTrigger: UUID = UUID()
    private var webSocketManager: WebSocketManager?
    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager()
    private var pendingActivities: [PendingActivity] = []
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private let cacheExpirationSeconds: TimeInterval = 1800 // 30 phút
    private let reachability = try? NWPathMonitor()
    private let coreDataStack = CoreDataStack.shared // Thêm CoreDataStack

    init(trip: TripModel) {
        self.trip = trip
        print("🚀 Khởi tạo TripDetailViewModel cho tripId=\(trip.id), instance: \(Unmanaged.passUnretained(self).toOpaque())")
        if let cachedTripDays = loadFromCache() {
            self.tripDaysData = cachedTripDays
            self.tripDays = cachedTripDays.compactMap { dateFormatter.date(from: $0.day) }.sorted() // Sắp xếp sau khi map
            self.objectWillChange.send()
            self.refreshTrigger = UUID()
        } else {
            fetchTripDays(forceRefresh: true)
        }
        setupNetworkMonitoring()
        loadPendingActivities()
    }

    private func parseActivity(from data: [String: Any]) -> TripActivity? {
        guard let id = data["id"] as? Int,
              let activityName = data["activity"] as? String,
              let tripDayId = data["trip_day_id"] as? Int else {
            print("❌ Lỗi khi parse activity: Missing required fields in \(data)")
            return nil
        }
        let estimatedCost = (data["estimated_cost"] as? Double) ?? (data["estimated_cost"] as? Int).map(Double.init) ?? 0.0
        let actualCost = (data["actual_cost"] as? Double) ?? (data["actual_cost"] as? Int).map(Double.init) ?? 0.0
        return TripActivity(
            id: id,
            tripDayId: tripDayId,
            startTime: data["start_time"] as? String ?? "",
            endTime: data["end_time"] as? String ?? "",
            activity: activityName,
            address: data["address"] as? String ?? "",
            estimatedCost: estimatedCost,
            actualCost: actualCost,
            note: data["note"] as? String ?? "",
            createdAt: data["created_at"] as? String ?? "",
            updatedAt: data["updated_at"] as? String ?? "",
            images: data["images"] as? [String] ?? nil
        )
    }

    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        reachability?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    print("🌐 Mạng đã được khôi phục, thử lại các hoạt động pending")
                    self?.retryPendingActivities()
                } else {
                    print("🌐 Mất kết nối mạng")
                }
            }
        }
        reachability?.start(queue: .global(qos: .background))
    }

    private func isNetworkAvailable() -> Bool {
        return reachability?.currentPath.status == .satisfied
    }

    // MARK: - Pending Activities
    private func savePendingActivities() {
        do {
            let data = try JSONEncoder().encode(pendingActivities)
            UserDefaults.standard.set(data, forKey: "pending_activities_\(trip.id)")
            print("💾 Đã lưu \(pendingActivities.count) hoạt động pending")
        } catch {
            print("❌ Lỗi khi lưu pending activities: \(error.localizedDescription)")
        }
    }

    private func loadPendingActivities() {
        guard let data = UserDefaults.standard.data(forKey: "pending_activities_\(trip.id)") else {
            print("⚠️ Không có pending activities cho tripId=\(trip.id)")
            return
        }
        do {
            pendingActivities = try JSONDecoder().decode([PendingActivity].self, from: data)
            print("📂 Đã tải \(pendingActivities.count) hoạt động pending")
            if !pendingActivities.isEmpty {
                retryPendingActivities()
            }
        } catch {
            print("❌ Lỗi khi tải pending activities: \(error.localizedDescription)")
        }
    }

    private func retryPendingActivities() {
        guard !pendingActivities.isEmpty else {
            print("✅ Không có hoạt động pending để thử lại")
            return
        }
        guard isNetworkAvailable() else {
            print("⚠️ Vẫn không có mạng, không thử lại pending activities")
            return
        }
        let activitiesToRetry = pendingActivities
        pendingActivities.removeAll()
        savePendingActivities()
        for pending in activitiesToRetry {
            switch pending.action {
            case .add:
                addActivity(trip: trip, date: pending.date, activity: pending.activity) { _ in }
            case .update:
                updateActivity(trip: trip, date: pending.date, activity: pending.activity) { _ in }
            }
        }
    }

    // MARK: - Activity Management
    func addActivity(trip: TripModel, date: Date, activity: TripActivity, completion: @escaping (Result<TripActivity, Error>) -> Void) {
        let dateString = dateFormatter.string(from: date)
        guard let tripDay = tripDaysData.first(where: { $0.day == dateString }) else {
            print("❌ Không tìm thấy trip day cho ngày: \(dateString)")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy ngày chuyến đi"])))
            return
        }
        
        let newActivity = TripActivity(
            id: activity.id,
            tripDayId: tripDay.id,
            startTime: activity.startTime,
            endTime: activity.endTime,
            activity: activity.activity,
            address: activity.address,
            estimatedCost: activity.estimatedCost,
            actualCost: activity.actualCost,
            note: activity.note,
            createdAt: activity.createdAt,
            updatedAt: activity.updatedAt,
            images: activity.images
        )
        
        addActivityToTripDays(newActivity)
        saveToCache(tripDays: tripDaysData)
        objectWillChange.send()
        refreshTrigger = UUID()
        showToast(message: "Đã thêm hoạt động cục bộ: \(newActivity.activity)")
        print("📅 Đã thêm hoạt động cục bộ: \(newActivity.activity)")

        if !isNetworkAvailable() {
            print("🌐 Mất mạng, lưu hoạt động vào pending activities")
            pendingActivities.append(PendingActivity(action: .add, activity: newActivity, date: date))
            savePendingActivities()
            completion(.success(newActivity))
            return
        }

        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(trip.id)/days/\(tripDay.id)/activities"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ URL hoặc Token không hợp lệ")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL hoặc Token không hợp lệ"])))
            return
        }

        let body: [String: Any] = [
            "activity": newActivity.activity,
            "address": newActivity.address,
            "start_time": newActivity.startTime,
            "end_time": newActivity.endTime,
            "estimated_cost": newActivity.estimatedCost,
            "actual_cost": newActivity.actualCost,
            "note": newActivity.note
        ]

        print("📤 Gửi body API: \(body)")

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            print("❌ Lỗi khi tạo JSON")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Lỗi khi tạo JSON"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        isLoading = true
        networkManager.performRequest(request, decodeTo: TripActivityResponse.self)
            .sink { [weak self] completionResult in
                self?.isLoading = false
                switch completionResult {
                case .failure(let error):
                    print("❌ Lỗi khi thêm hoạt động qua API: \(error.localizedDescription)")
                    self?.showToast(message: "Lỗi khi đồng bộ hoạt động với server")
                    self?.removeActivityFromTripDays(activityId: newActivity.id, tripDayId: tripDay.id)
                    self?.saveToCache(tripDays: self?.tripDaysData ?? [])
                    self?.objectWillChange.send()
                    self?.refreshTrigger = UUID()
                    completion(.failure(error))
                case .finished:
                    print("✅ Thêm hoạt động qua API hoàn tất")
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                if let addedActivity = response.data {
                    if self.isActivityEqual(localActivity: newActivity, serverActivity: addedActivity) {
                        print("✅ Dữ liệu hoạt động từ API khớp với cục bộ: \(addedActivity.activity)")
                        self.showToast(message: "Đã đồng bộ hoạt động: \(addedActivity.activity)")
                        completion(.success(addedActivity))
                    } else {
                        print("⚠️ Dữ liệu hoạt động không khớp, cập nhật với dữ liệu từ API")
                        self.updateActivityInTripDays(addedActivity)
                        self.saveToCache(tripDays: self.tripDaysData)
                        self.objectWillChange.send()
                        self.refreshTrigger = UUID()
                        self.showToast(message: "Đã cập nhật hoạt động từ server: \(addedActivity.activity)")
                        completion(.success(addedActivity))
                    }
                } else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không nhận được dữ liệu hoạt động"])
                    print("❌ Không nhận được dữ liệu hoạt động từ API")
                    self.showToast(message: "Đồng bộ hoạt động thất bại")
                    self.removeActivityFromTripDays(activityId: newActivity.id, tripDayId: tripDay.id)
                    self.saveToCache(tripDays: self.tripDaysData)
                    self.objectWillChange.send()
                    self.refreshTrigger = UUID()
                    completion(.failure(error))
                }
            }
            .store(in: &cancellables)
    }

    func updateActivity(trip: TripModel, date: Date, activity: TripActivity, completion: @escaping (Result<TripActivity, Error>) -> Void) {
        let dateString = dateFormatter.string(from: date)
        print("📅 DateString: \(dateString), Available TripDays: \(tripDaysData.map { $0.day })")
        
        guard let tripDay = tripDaysData.first(where: { $0.day == dateString }) else {
            print("❌ Không tìm thấy trip day cho ngày: \(dateString)")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy ngày chuyến đi"])))
            return
        }
        
        guard activity.tripDayId == tripDay.id else {
            print("❌ TripDayId không khớp: activity.tripDayId=\(activity.tripDayId), expected=\(tripDay.id)")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "TripDayId không khớp"])))
            return
        }
        
        updateActivityInTripDays(activity)
        saveToCache(tripDays: tripDaysData)
        objectWillChange.send()
        refreshTrigger = UUID()
        showToast(message: "Đã cập nhật hoạt động cục bộ: \(activity.activity)")
        print("📅 Đã cập nhật hoạt động cục bộ: \(activity.activity)")

        if !isNetworkAvailable() {
            print("🌐 Mất mạng, lưu cập nhật vào pending activities")
            pendingActivities.append(PendingActivity(action: .update, activity: activity, date: date))
            savePendingActivities()
            completion(.success(activity))
            return
        }

        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(trip.id)/days/\(tripDay.id)/activities/\(activity.id)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ URL hoặc Token không hợp lệ")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL hoặc Token không hợp lệ"])))
            return
        }
        
        let body: [String: Any] = [
            "activity": activity.activity,
            "address": activity.address,
            "start_time": activity.startTime,
            "end_time": activity.endTime,
            "estimated_cost": Int(activity.estimatedCost),
            "actual_cost": Int(activity.actualCost),
            "note": activity.note
        ]
        
        print("📤 Gửi body API cập nhật: \(body)")
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            print("❌ Lỗi khi tạo JSON")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Lỗi khi tạo JSON"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        isLoading = true
        networkManager.performRequest(request, decodeTo: TripActivityUpdateResponse.self)
            .sink { [weak self] completionResult in
                self?.isLoading = false
                switch completionResult {
                case .failure(let error as NSError):
                    print("❌ Lỗi khi cập nhật hoạt động qua API: \(error.localizedDescription)")
                    if error.code == -1011 { // 403 Forbidden
                        self?.showToast(message: "Bạn không có quyền cập nhật hoạt động này")
                        self?.fetchTripDays(forceRefresh: true)
                        self?.objectWillChange.send()
                        self?.refreshTrigger = UUID()
                    } else {
                        self?.showToast(message: "Lỗi khi đồng bộ hoạt động: \(error.localizedDescription)")
                        self?.fetchTripDays(forceRefresh: true)
                        self?.objectWillChange.send()
                        self?.refreshTrigger = UUID()
                    }
                    completion(.failure(error))
                case .finished:
                    print("✅ Cập nhật hoạt động qua API hoàn tất")
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                if let updatedActivity = response.data?.updatedActivity {
                    if self.isActivityEqual(localActivity: activity, serverActivity: updatedActivity) {
                        print("✅ Dữ liệu cập nhật từ API khớp với cục bộ: \(updatedActivity.activity)")
                        self.showToast(message: "Đã đồng bộ hoạt động: \(updatedActivity.activity)")
                        completion(.success(updatedActivity))
                    } else {
                        print("⚠️ Dữ liệu cập nhật không khớp, cập nhật với dữ liệu từ API")
                        self.updateActivityInTripDays(updatedActivity)
                        self.saveToCache(tripDays: self.tripDaysData)
                        self.objectWillChange.send()
                        self.refreshTrigger = UUID()
                        self.showToast(message: "Đã cập nhật hoạt động từ server: \(updatedActivity.activity)")
                        completion(.success(updatedActivity))
                    }
                } else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không nhận được dữ liệu hoạt động"])
                    print("❌ Không nhận được dữ liệu hoạt động từ API")
                    self.showToast(message: "Đồng bộ hoạt động thất bại")
                    self.fetchTripDays(forceRefresh: true)
                    self.objectWillChange.send()
                    self.refreshTrigger = UUID()
                    completion(.failure(error))
                }
            }
            .store(in: &cancellables)
    }

    func deleteActivity(activityId: Int, tripDayId: Int, completion: @escaping () -> Void) {
        guard isNetworkAvailable() else {
            print("🌐 Mất mạng, không cho phép xóa hoạt động")
            showToast(message: "Không thể xóa hoạt động khi không có kết nối mạng")
            completion()
            return
        }

        guard let token = UserDefaults.standard.string(forKey: "authToken"),
              let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(trip.id)/days/\(tripDayId)/activities/\(activityId)") else {
            showToast(message: "URL hoặc token không hợp lệ")
            completion()
            return
        }

        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
        isLoading = true

        networkManager.performRequest(request, decodeTo: BaseResponse.self)
            .sink { [weak self] result in
                self?.isLoading = false
                switch result {
                case .failure(let error as NSError):
                    print("❌ Lỗi khi xóa hoạt động: \(error.localizedDescription)")
                    if error.code == -1011 { // 403 Forbidden
                        self?.showToast(message: "Bạn không có quyền xóa hoạt động này")
                    } else {
                        self?.showToast(message: "Lỗi khi xóa hoạt động: \(error.localizedDescription)")
                    }
                    completion()
                case .finished:
                    print("✅ Xóa hoạt động hoàn tất")
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                if response.success {
                    self.removeActivityFromTripDays(activityId: activityId, tripDayId: tripDayId)
                    self.saveToCache(tripDays: self.tripDaysData)
                    self.objectWillChange.send()
                    self.refreshTrigger = UUID()
                    self.showToast(message: response.message ?? "Đã xóa hoạt động")
                    completion()
                } else {
                    self.showToast(message: response.message ?? "Xóa thất bại")
                    completion()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Helper Methods
    private func addActivityToTripDays(_ activity: TripActivity) {
        clearCache()
        guard let index = tripDaysData.firstIndex(where: { $0.id == activity.tripDayId }) else {
            print("❌ Không tìm thấy trip day với id: \(activity.tripDayId), fetching lại...")
            fetchTripDays(forceRefresh: true)
            return
        }
        if tripDaysData[index].activities.contains(where: { $0.id == activity.id }) {
            print("⚠️ Hoạt động đã tồn tại: \(activity.activity)")
            return
        }
        tripDaysData[index].activities.append(activity)
        updateTripDays()
        print("📅 Đã thêm hoạt động vào trip day \(tripDaysData[index].day): \(activity.activity)")
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.refreshTrigger = UUID()
        }
    }

    private func updateActivityInTripDays(_ activity: TripActivity) {
        clearCache()
        guard let dayIndex = tripDaysData.firstIndex(where: { $0.id == activity.tripDayId }),
              let activityIndex = tripDaysData[dayIndex].activities.firstIndex(where: { $0.id == activity.id }) else {
            print("❌ Không tìm thấy trip day hoặc activity để cập nhật, fetching lại...")
            fetchTripDays(forceRefresh: true)
            return
        }
        tripDaysData[dayIndex].activities[activityIndex] = activity
        updateTripDays()
        print("📅 Đã cập nhật hoạt động trong trip day \(tripDaysData[dayIndex].day): \(activity.activity)")
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.refreshTrigger = UUID()
        }
    }

    private func removeActivityFromTripDays(activityId: Int, tripDayId: Int) {
        clearCache()
        guard let dayIndex = tripDaysData.firstIndex(where: { $0.id == tripDayId }) else {
            print("❌ Không tìm thấy trip day với id: \(tripDayId), fetching lại...")
            fetchTripDays(forceRefresh: true)
            return
        }
        tripDaysData[dayIndex].activities.removeAll { $0.id == activityId }
        updateTripDays()
        print("📅 Đã xóa hoạt động \(activityId) khỏi trip day \(tripDayId)")
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.refreshTrigger = UUID()
        }
    }

    private func updateTripDays() {
        tripDays = tripDaysData.compactMap { dateFormatter.date(from: $0.day) }
        print("📅 Đã cập nhật tripDays: \(tripDays.map { dateFormatter.string(from: $0) })")
    }

    private func isActivityEqual(localActivity: TripActivity, serverActivity: TripActivity) -> Bool {
        return localActivity.activity == serverActivity.activity &&
               localActivity.address == serverActivity.address &&
               localActivity.startTime == serverActivity.startTime &&
               localActivity.endTime == serverActivity.endTime &&
               localActivity.estimatedCost == serverActivity.estimatedCost &&
               localActivity.actualCost == serverActivity.actualCost &&
               localActivity.note == serverActivity.note &&
               localActivity.tripDayId == serverActivity.tripDayId
    }

    func fetchTripDays(completion: (() -> Void)? = nil, forceRefresh: Bool = false) {
        print("📡 Bắt đầu fetchTripDays, forceRefresh=\(forceRefresh)")
        if !forceRefresh {
            if let cachedTripDays = loadFromCache() {
                self.tripDaysData = cachedTripDays
                self.tripDays = cachedTripDays.compactMap { dateFormatter.date(from: $0.day) }
                self.objectWillChange.send()
                self.refreshTrigger = UUID()
                completion?()
                return
            }
        } else {
            clearCache()
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(trip.id)/days"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ URL hoặc Token không hợp lệ")
            isLoading = false
            showToast(message: "URL hoặc token không hợp lệ")
            completion?()
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: TripDayResponse.self)
            .sink { [weak self] completionResult in
                self?.isLoading = false
                self?.handleCompletion(completionResult, completionHandler: completion)
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                if let tripDays = response.data?.tripDays {
                    print("📡 API trả về \(tripDays.count) ngày:")
                    for day in tripDays {
                        print("📅 Ngày \(day.day): \(day.activities.map { "\($0.activity) (ID: \($0.id))" })")
                    }
                    self.tripDaysData = tripDays
                    self.tripDays = tripDays.compactMap { self.dateFormatter.date(from: $0.day) }
                    self.objectWillChange.send()
                    self.refreshTrigger = UUID()
                    self.saveToCache(tripDays: tripDays)
                    print("📅 Fetch trip days thành công: \(tripDays.count) ngày")
                } else {
                    print("⚠️ Không có dữ liệu trip days")
                    self.showToast(message: "Không có dữ liệu ngày chuyến đi")
                }
                completion?()
            }
            .store(in: &cancellables)
    }

    func activities(for date: Date) -> [TripActivity] {
        let selectedDateString = dateFormatter.string(from: date)
        guard let tripDay = tripDaysData.first(where: { $0.day == selectedDateString }) else {
            print("❌ Không tìm thấy TripDay cho ngày: \(selectedDateString)")
            return []
        }
        let activities = tripDay.activities
        return activities
    }
    
    func calculateTotalCosts(for date: Date) -> (actualCost: Double, estimatedCost: Double) {
        let activities = activities(for: date)
        let totalActualCost = activities.reduce(0.0) { $0 + $1.actualCost }
        let totalEstimatedCost = activities.reduce(0.0) { $0 + $1.estimatedCost }
        return (totalActualCost, totalEstimatedCost)
    }
    
    func getTripDayId(for date: Date, completion: @escaping (Int?) -> Void) {
        let dateString = dateFormatter.string(from: date)
        if let tripDay = tripDaysData.first(where: { $0.day == dateString }) {
            print("✅ Đã lấy tripDayId: \(tripDay.id) cho ngày: \(dateString)")
            completion(tripDay.id)
        } else {
            print("❌ Không tìm thấy TripDay cho ngày: \(dateString)")
            completion(nil)
        }
    }

    private func saveToCache(tripDays: [TripDay]) {
        let context = coreDataStack.context
        clearCache()
        for tripDay in tripDays {
            let _ = tripDay.toEntity(context: context)
        }
        do {
            try context.save()
            print("💾 Đã lưu cache trip days cho tripId=\(trip.id) với \(tripDays.count) ngày")
        } catch {
            print("❌ Lỗi lưu Core Data: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] as? [NSError] {
                    for validationError in detailedErrors {
                        print("Validation error: \(validationError.localizedDescription)")
                    }
                } else {
                    print("Không tìm thấy lỗi chi tiết trong userInfo")
                }
            }
            showToast(message: "Lỗi khi lưu cache dữ liệu")
        }
    }

    private func loadFromCache() -> [TripDay]? {
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<TripDayEntity> = TripDayEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tripId == %d", trip.id)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "day", ascending: true)] // Sắp xếp theo day tăng dần
        do {
            let entities = try context.fetch(fetchRequest)
            let tripDays = entities.map { TripDay(from: $0) }
            print("📂 Đã đọc cache với \(tripDays.count) ngày cho tripId=\(trip.id), sorted by day")
            return tripDays.isEmpty ? nil : tripDays
        } catch {
            print("❌ Lỗi khi đọc cache: \(error.localizedDescription)")
            showToast(message: "Dữ liệu cache bị lỗi")
            return nil
        }
    }

    private func handleCompletion(_ completion: Subscribers.Completion<Error>, completionHandler: (() -> Void)? = nil) {
        switch completion {
        case .failure(let error):
            print("❌ Lỗi khi fetch trip days: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("🔍 Data corrupted: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("🔍 Key '\(key)' not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("🔍 Type '\(type)' mismatch: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("🔍 Value '\(type)' not found: \(context.debugDescription)")
                @unknown default:
                    print("🔍 Lỗi decode không xác định")
                }
            }
            showToast(message: "Lỗi khi tải dữ liệu ngày chuyến đi")
        case .finished:
            print("✅ Fetch trip days hoàn tất")
        }
        completionHandler?()
    }

    private func clearCache() {
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TripDayEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tripId == %d", trip.id)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            try context.save()
            print("🗑️ Đã xóa cache trip days cho tripId=\(trip.id)")
        } catch {
            print("❌ Lỗi khi xóa cache: \(error.localizedDescription)")
        }
    }

    func showToast(message: String) {
        print("📢 Đặt toast: \(message)")
        DispatchQueue.main.async {
            self.toastMessage = message
            self.showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                print("📢 Ẩn toast")
                self.showToast = false
                self.toastMessage = nil
            }
        }
    }
}
