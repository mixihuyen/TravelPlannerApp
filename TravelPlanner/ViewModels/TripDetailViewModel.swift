
import Foundation
import Combine
import SwiftUI

class TripDetailViewModel: ObservableObject {
    let trip: TripModel
    @Published var tripDays: [Date] = []
    @Published var tripDaysData: [TripDay] = []
    @Published var isLoading: Bool = false
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    @Published var refreshTrigger: UUID = UUID()

    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    init(trip: TripModel) {
        self.trip = trip
        print("🚀 Khởi tạo TripDetailViewModel cho tripId=\(trip.id)")
        loadFromCache()
        fetchTripDays(forceRefresh: true) // Làm mới ngay khi khởi tạo
    }

    func fetchTripDays(completion: (() -> Void)? = nil, forceRefresh: Bool = false) {
        print("📡 Bắt đầu fetchTripDays, forceRefresh=\(forceRefresh)")
        if !forceRefresh {
            if let cachedTripDays = loadFromCache() {
                print("📂 Sử dụng dữ liệu từ cache: \(cachedTripDays.map { ($0.day, $0.activities.map { $0.activity }) })")
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
        print("📋 Truy cập activities cho ngày \(selectedDateString), tripDaysData: \(tripDaysData.map { ($0.day, $0.activities.map { $0.activity }) })")
        guard let tripDay = tripDaysData.first(where: { $0.day == selectedDateString }) else {
            print("❌ Không tìm thấy TripDay cho ngày: \(selectedDateString)")
            return []
        }
        let activities = tripDay.activities
        print("📋 Hoạt động cho ngày \(selectedDateString): \(activities.map { "\($0.activity) (ID: \($0.id))" })")
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
                    self.clearCache()
                    self.fetchTripDays(completion: {
                        print("📋 Dữ liệu tripDaysData sau khi thêm: \(self.tripDaysData.map { ($0.day, $0.activities.map { $0.activity }) })")
                    }, forceRefresh: true)
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
        
        clearCache() // Xóa cache trước khi cập nhật
        performUpdateActivity(trip: trip, activity: activity, tripDayId: tripDay.id, token: token, completion: completion)
    }
    
    private func performUpdateActivity(trip: TripModel, activity: TripActivity, tripDayId: Int, token: String, completion: @escaping (Result<TripActivity, Error>) -> Void) {
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(trip.id)/days/\(tripDayId)/activities/\(activity.id)") else {
            print("❌ URL không hợp lệ")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL không hợp lệ"])))
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
                    print("📋 Dữ liệu hoạt động cập nhật: \(updatedActivity)")
                    self.showToast(message: "Đã cập nhật hoạt động: \(updatedActivity.activity)")
                    self.clearCache()
                    self.fetchTripDays(completion: {
                        print("📋 Dữ liệu tripDaysData sau khi cập nhật: \(self.tripDaysData.map { ($0.day, $0.activities.map { $0.activity }) })")
                    }, forceRefresh: true)
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
                    self.showToast(message: response.message ?? "Đã xóa hoạt động")
                    self.clearCache()
                    self.fetchTripDays(completion: {
                        print("📋 Dữ liệu tripDaysData sau khi xóa: \(self.tripDaysData.map { ($0.day, $0.activities.map { $0.activity }) })")
                    }, forceRefresh: true)
                    completion()
                } else {
                    self.showToast(message: response.message ?? "Xóa thất bại")
                    completion()
                }
            }
            .store(in: &cancellables)
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

    private func saveToCache(tripDays: [TripDay]) {
        do {
            let data = try JSONEncoder().encode(tripDays)
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
            let tripDays = try JSONDecoder().decode([TripDay].self, from: data)
            print("📂 Đã tải cache trip days cho tripId=\(trip.id): \(tripDays.map { ($0.day, $0.activities.map { $0.activity }) })")
            return tripDays
        } catch {
            print("❌ Lỗi khi đọc cache trip days: \(error.localizedDescription)")
            return nil
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

    func clearCache() {
        UserDefaults.standard.removeObject(forKey: "trip_days_cache_\(trip.id)")
        print("🗑️ Đã xóa cache trip days cho tripId=\(trip.id)")
    }
}
