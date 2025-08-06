import Foundation
import Combine
import SwiftUI

// MARK: - Trip Detail ViewModel
class TripDetailViewModel: ObservableObject {
    let trip: TripModel
    @Published var tripDays: [Date] = []
    @Published var tripDaysData: [TripDay] = []
    @Published var isLoading: Bool = false
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false

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
        loadFromCache()
        fetchTripDays()
    }

    // MARK: - Public Methods
    func fetchTripDays(completion: (() -> Void)? = nil, forceRefresh: Bool = false) {
            if !forceRefresh, let cachedTripDays = loadFromCache() {
                print("📂 Sử dụng dữ liệu từ cache: \(cachedTripDays.map { ($0.day, $0.activities.map { $0.activity }) })")
                self.tripDaysData = cachedTripDays
                self.tripDays = cachedTripDays.compactMap { dateFormatter.date(from: $0.day) }
                completion?()
                return
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(trip.id)/days"),
                  let token = UserDefaults.standard.string(forKey: "authToken") else {
                print("❌ URL hoặc Token không hợp lệ")
                isLoading = false
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
                        self.saveToCache(tripDays: tripDays)
                        print("📅 Fetch trip days thành công: \(tripDays.count) ngày")
                    } else {
                        print("⚠️ Không có dữ liệu trip days")
                        self.showToast(message: "Không có dữ liệu ngày chuyến đi")
                    }
                }
                .store(in: &cancellables)
        }

    func activities(for date: Date) -> [TripActivity] {
        let selectedDateString = dateFormatter.string(from: date)
        // Lọc tất cả hoạt động có start_time thuộc ngày được chọn
        let allActivities = tripDaysData.flatMap { $0.activities }
        let filteredActivities = allActivities.filter { activity in
            let startTimeDate = Formatter.apiDateTimeFormatter.date(from: activity.startTime)
            let startTimeDateString = startTimeDate != nil ? dateFormatter.string(from: startTimeDate!) : ""
            return startTimeDateString == selectedDateString
        }
        print("📋 Hoạt động cho ngày \(selectedDateString): \(filteredActivities.map { "\($0.activity) (ID: \($0.id))" })")
        return filteredActivities
    }
    
    func calculateTotalCosts(for date: Date) -> (actualCost: Double, estimatedCost: Double) {
            let activities = activities(for: date)
            let totalActualCost = activities.reduce(0.0) { $0 + $1.actualCost }
            let totalEstimatedCost = activities.reduce(0.0) { $0 + $1.estimatedCost }
            return (totalActualCost, totalEstimatedCost)
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
            
            // Kiểm tra định dạng start_time và end_time
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
                } receiveValue: { response in
                    if let addedActivity = response.data {
                        print("📅 Thêm hoạt động thành công: \(addedActivity.activity)")
                        completion(.success(addedActivity))
                    } else {
                        let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không nhận được dữ liệu hoạt động"])
                        print("❌ Không nhận được dữ liệu hoạt động")
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
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(trip.id)/days/\(tripDay.id)/activities/\(activity.id)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ URL hoặc Token không hợp lệ")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL hoặc Token không hợp lệ"])))
            return
        }
        
        print("📍 URL: \(url.absoluteString)")
        print("🔑 Token: \(token)")
        
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
                case .failure(let error):
                    print("❌ Lỗi khi cập nhật hoạt động: \(error.localizedDescription)")
                    self?.showToast(message: "Lỗi khi cập nhật hoạt động")
                    completion(.failure(error))
                case .finished:
                    print("✅ Cập nhật hoạt động hoàn tất")
                }
            } receiveValue: { response in
                if let updatedActivity = response.data?.updatedActivity {
                    print("📅 Cập nhật hoạt động thành công: \(updatedActivity.activity)")
                    self.showToast(message: "Cập nhật hoạt động thành công")
                    completion(.success(updatedActivity))
                } else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không nhận được dữ liệu hoạt động"])
                    print("❌ Không nhận được dữ liệu hoạt động")
                    completion(.failure(error))
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Private Methods
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
        } catch {
            print("❌ Lỗi khi lưu cache trip days: \(error.localizedDescription)")
            showToast(message: "Lỗi khi lưu cache dữ liệu")
        }
    }

    private func loadFromCache() -> [TripDay]? {
        guard let data = UserDefaults.standard.data(forKey: "trip_days_cache_\(trip.id)") else {
            return nil
        }
        do {
            let tripDays = try JSONDecoder().decode([TripDay].self, from: data)
            return tripDays
        } catch {
            print("❌ Lỗi khi đọc cache trip days: \(error.localizedDescription)")
            return nil
        }
    }

    private func showToast(message: String) {
        print("📢 Đặt toast: \(message)")
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("📢 Ẩn toast")
            self.showToast = false
            self.toastMessage = nil
        }
    }
}
