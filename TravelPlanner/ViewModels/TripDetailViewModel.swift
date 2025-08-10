import Foundation
import Combine
import SwiftUI

struct CachedTripDays: Codable {
    let timestamp: Date
    let data: [TripDay]
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
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private let cacheExpirationSeconds: TimeInterval = 1800 // 30 phút

    init(trip: TripModel) {
            self.trip = trip
            print("🚀 Khởi tạo TripDetailViewModel cho tripId=\(trip.id), instance: \(Unmanaged.passUnretained(self).toOpaque())")
            if let cachedTripDays = loadFromCache() {
                self.tripDaysData = cachedTripDays
                self.tripDays = cachedTripDays.compactMap { dateFormatter.date(from: $0.day) }
                self.objectWillChange.send()
                self.refreshTrigger = UUID()
            } else {
                fetchTripDays(forceRefresh: true)
            }
        connectWebSocket()
        }
    
    deinit {
        disconnectWebSocket()
        cancellables.removeAll()
        print("🗑️ TripDetailViewModel deinit, instance: \(Unmanaged.passUnretained(self).toOpaque())")
    }

    func connectWebSocket() {
        guard webSocketManager == nil || webSocketManager?.socket?.status != .connected else {
            print("⚠️ WebSocket đã kết nối, bỏ qua")
            return
        }
        
        WebSocketService.shared.connect(tripId: trip.id)
            webSocketManager = WebSocketService.shared.manager(for: trip.id)
            webSocketManager?.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self else { return }
                switch message {
                case .connected:
                    print("✅ WebSocket connected")
                    showToast(message: "Đã kết nối thời gian thực")
                case .disconnected(let reason, let code):
                    print("❌ WebSocket disconnected: \(reason) (code: \(code))")
                    showToast(message: "Mất kết nối thời gian thực")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.connectWebSocket()
                    }
                case .message(let json):
                    handleWebSocketMessage(json)
                case .error(let error):
                    print("❌ WebSocket error: \(error?.localizedDescription ?? "Unknown error")")
                    showToast(message: "Lỗi kết nối thời gian thực")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.connectWebSocket()
                    }
                }
            }
            .store(in: &cancellables)
    }

    func disconnectWebSocket() {
        WebSocketService.shared.disconnect(tripId: trip.id)
        webSocketManager = nil
    }

        

     func handleWebSocketMessage(_ json: [String: Any]) {
        guard let eventType = json["event"] as? String else {
            print("❌ Không tìm thấy eventType trong WebSocket message: \(json)")
            return
        }
        
        switch eventType {
        case "newActivity":
            if let activityData = json["activity"] as? [String: Any],
               let activity = parseActivity(from: activityData) {
                print("📥 New activity received: \(activity.activity)")
                addActivityToTripDays(activity)
                saveToCache(tripDays: tripDaysData)
                objectWillChange.send()
                refreshTrigger = UUID()
                showToast(message: "Hoạt động mới: \(activity.activity)")
            }
        case "updateActivity":
            if let activityData = json["data"] as? [String: Any],
               let activity = parseActivity(from: activityData) {
                print("📥 Updated activity received: \(activity.activity)")
                updateActivityInTripDays(activity)
                saveToCache(tripDays: tripDaysData)
                objectWillChange.send()
                refreshTrigger = UUID()
                showToast(message: "Đã cập nhật: \(activity.activity)")
            }
        case "deleteActivity":
            if let activityId = json["activityId"] as? Int,
               let tripDayId = json["tripDayId"] as? Int {
                print("📥 Delete activity received: activityId=\(activityId), tripDayId=\(tripDayId)")
                removeActivityFromTripDays(activityId: activityId, tripDayId: tripDayId)
                saveToCache(tripDays: tripDaysData)
                objectWillChange.send()
                refreshTrigger = UUID()
                showToast(message: "Đã xóa hoạt động")
            }
        case "newParticipant":
            if let participantData = json["data"] as? [String: Any] {
                print("📥 New participant: \(participantData)")
                showToast(message: "Thành viên mới tham gia chuyến đi")
                // TODO: Thêm logic xử lý thành viên mới nếu cần
            }
        case "updateParticipant":
            if let participantData = json["data"] as? [String: Any] {
                print("📥 Updated participant: \(participantData)")
                showToast(message: "Quyền thành viên đã được cập nhật")
                // TODO: Thêm logic xử lý cập nhật thành viên nếu cần
            }
        case "deleteParticipant":
            if let participantData = json["data"] as? [String: Any] {
                print("📥 Deleted participant: \(participantData)")
                showToast(message: "Thành viên đã rời hoặc bị xóa khỏi chuyến đi")
                // TODO: Thêm logic xử lý xóa thành viên nếu cần
            }
        default:
            print("⚠️ Sự kiện WebSocket không xác định: \(eventType)")
        }
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

    func fetchTripDays(completion: (() -> Void)? = nil, forceRefresh: Bool = false) {
        print("📡 Bắt đầu fetchTripDays, forceRefresh=\(forceRefresh)")
        if !forceRefresh {
            if let cachedTripDays = loadFromCache() {
                //print("📂 Sử dụng dữ liệu từ cache: \(cachedTripDays.map { ($0.day, $0.activities.map { $0.activity }) })")
                self.tripDaysData = cachedTripDays
                self.tripDays = cachedTripDays.compactMap { dateFormatter.date(from: $0.day) }
                self.objectWillChange.send()
                self.refreshTrigger = UUID()
                completion?()
                return
            }
        } else {
            clearCache() // Xóa cache trước khi fetch từ API
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
        //print("📋 Truy cập activities cho ngày \(selectedDateString), tripDaysData: \(tripDaysData.map { ($0.day, $0.activities.map { $0.activity }) })")
        guard let tripDay = tripDaysData.first(where: { $0.day == selectedDateString }) else {
            print("❌ Không tìm thấy TripDay cho ngày: \(selectedDateString)")
            return []
        }
        let activities = tripDay.activities
        //print("📋 Hoạt động cho ngày \(selectedDateString): \(activities.map { "\($0.activity) (ID: \($0.id))" })")
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

    func addActivity(trip: TripModel, date: Date, activity: TripActivity, completion: @escaping (Result<TripActivity, Error>) -> Void) {
        let dateString = dateFormatter.string(from: date)
        guard let tripDay = tripDaysData.first(where: { $0.day == dateString }) else {
            print("❌ Không tìm thấy trip day cho ngày: \(dateString)")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy ngày chuyến đi"])))
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(trip.id)/days/\(tripDay.id)/activities"),
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
            "estimated_cost": activity.estimatedCost,
            "actual_cost": activity.actualCost,
            "note": activity.note
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
                    print("❌ Lỗi khi thêm hoạt động: \(error.localizedDescription)")
                    self?.showToast(message: "Lỗi khi thêm hoạt động")
                    completion(.failure(error))
                case .finished:
                    print("✅ Thêm hoạt động hoàn tất")
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                if let addedActivity = response.data {
                    print("📅 Thêm hoạt động thành công: \(addedActivity.activity)")
                    self.showToast(message: "Đã thêm hoạt động: \(addedActivity.activity)")
                    self.addActivityToTripDays(addedActivity)
                    self.saveToCache(tripDays: self.tripDaysData)
                    self.objectWillChange.send()
                    self.refreshTrigger = UUID()
                    completion(.success(addedActivity))
                } else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không nhận được dữ liệu hoạt động"])
                    print("❌ Không nhận được dữ liệu hoạt động")
                    self.showToast(message: "Thêm hoạt động thất bại")
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
                    print("❌ Lỗi khi cập nhật hoạt động: \(error.localizedDescription)")
                    if error.code == -1011 { // 403 Forbidden
                        self?.showToast(message: "Bạn không có quyền cập nhật hoạt động này")
                    } else {
                        self?.showToast(message: "Lỗi khi cập nhật hoạt động: \(error.localizedDescription)")
                    }
                    completion(.failure(error))
                case .finished:
                    print("✅ Cập nhật hoạt động hoàn tất")
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                if let updatedActivity = response.data?.updatedActivity {
                    print("📅 Cập nhật hoạt động thành công: \(updatedActivity.activity)")
                    self.updateActivityInTripDays(updatedActivity)
                    self.saveToCache(tripDays: self.tripDaysData)
                    self.objectWillChange.send()
                    self.refreshTrigger = UUID()
                    self.showToast(message: "Đã cập nhật hoạt động: \(updatedActivity.activity)")
                    completion(.success(updatedActivity))
                } else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không nhận được dữ liệu hoạt động"])
                    print("❌ Không nhận được dữ liệu hoạt động")
                    self.showToast(message: "Cập nhật hoạt động thất bại")
                    completion(.failure(error))
                }
            }
            .store(in: &cancellables)
    }
    
    func deleteActivity(activityId: Int, tripDayId: Int, completion: @escaping () -> Void) {
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

    private func saveToCache(tripDays: [TripDay]) {
        let cached = CachedTripDays(timestamp: Date(), data: tripDays)
        do {
            let data = try JSONEncoder().encode(cached)
            UserDefaults.standard.set(data, forKey: "trip_days_cache_\(trip.id)")
            print("💾 Đã lưu cache trip days cho tripId=\(trip.id)")
        } catch {
            print("❌ Lỗi khi lưu cache trip days: \(error.localizedDescription)")
            showToast(message: "Lỗi khi lưu cache dữ liệu")
        }
    }

    private func loadFromCache() -> [TripDay]? {
        guard let data = UserDefaults.standard.data(forKey: "trip_days_cache_\(trip.id)") else {
            print("⚠️ Không tìm thấy cache trip days cho tripId=\(trip.id)")
            return nil
        }
        do {
            let cached = try JSONDecoder().decode(CachedTripDays.self, from: data)
            if Date().timeIntervalSince(cached.timestamp) > cacheExpirationSeconds {
                print("⚠️ Cache hết hạn, xóa cache")
                clearCache()
                return nil
            }
            //print("📂 Đã tải cache trip days cho tripId=\(trip.id): \(cached.data.map { ($0.day, $0.activities.map { $0.activity }) })")
            return cached.data
        } catch {
            print("❌ Lỗi khi đọc cache trip days: \(error.localizedDescription)")
            clearCache()
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

    func clearCache() {
        UserDefaults.standard.removeObject(forKey: "trip_days_cache_\(trip.id)")
        print("🗑️ Đã xóa cache trip days cho tripId=\(trip.id)")
    }
}
