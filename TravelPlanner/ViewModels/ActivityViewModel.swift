import Foundation
import CoreData
import Combine
import SwiftUI
import Network

class ActivityViewModel: ObservableObject {
    let tripId: Int
    @Published var activities: [TripActivity] = []
    @Published var isLoading: Bool = false
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    @Published var toastType: ToastType?
    @Published var refreshTrigger: UUID = UUID()
    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager.shared
    private let coreDataStack = CoreDataStack.shared

    init(tripId: Int) {
        self.tripId = tripId
        print("🚀 Initializing ActivityViewModel for tripId=\(tripId), instance: \(Unmanaged.passUnretained(self).toOpaque())")
        // Tải cache ban đầu nếu có
        if let cachedActivities = loadFromCache(), !cachedActivities.isEmpty {
            self.activities = cachedActivities
            self.refreshTrigger = UUID()
            print("📂 Initialized with \(cachedActivities.count) activities from cache")
        }
    }

    deinit {
        print("🗑️ ActivityViewModel deallocated for tripId=\(tripId)")
    }

    func fetchActivities(tripDayId: Int, completion: (() -> Void)? = nil, forceRefresh: Bool = false) {
        print("📡 Bắt đầu fetchActivities cho tripDayId=\(tripDayId), forceRefresh=\(forceRefresh), networkAvailable=\(networkManager.isNetworkAvailable)")
        
        // Nếu không yêu cầu forceRefresh, kiểm tra cache trước
        if !forceRefresh, let cachedActivities = loadFromCache()?.filter({ $0.tripDayId == tripDayId }), !cachedActivities.isEmpty {
            self.activities = cachedActivities
            self.refreshTrigger = UUID()
            print("📂 Using cache with \(cachedActivities.count) activities for tripDayId=\(tripDayId): \(cachedActivities.map { "\($0.activity) (ID: \($0.id))" })")
        }
        
        // Kiểm tra mạng để thực hiện fetch ngầm
        guard networkManager.isNetworkAvailable else {
            print("🌐 No network, using cache only")
            if activities.isEmpty {
                showToast(message: "Không có kết nối mạng, không có dữ liệu cache", type: .error)
            }
            completion?()
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/days/\(tripDayId)/activities"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ Invalid URL or Token")
            showToast(message: "Đã xảy ra lỗi, vui lòng thử lại", type: .error)
            completion?()
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        isLoading = true
        
        networkManager.performRequest(request, decodeTo: TripActivityListResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                self.isLoading = false
                switch completionResult {
                case .failure(let error):
                    print("❌ Error fetching activities: \(error.localizedDescription)")
                    if self.activities.isEmpty {
                        showToast(message: "Không thể tải danh sách hoạt động", type: .error)
                    }
                    completion?()
                case .finished:
                    print("✅ Fetching activities completed")
                    completion?()
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.success, let newActivities = response.data {
                    print("📋 Received \(newActivities.count) activities from API: \(newActivities.map { "\($0.activity) (ID: \($0.id))" })")
                    
                    // So sánh dữ liệu API với cache
                    let cachedActivities = self.activities
                    if newActivities != cachedActivities {
                        print("🔄 API data differs from cache, updating activities")
                        self.activities = newActivities
                        self.saveToCache(activities: newActivities)
                        self.refreshTrigger = UUID()
                    } else {
                        print("✅ API data matches cache, no UI update needed")
                    }
                } else {
                    print("❌ No activity data received from API")
                    if self.activities.isEmpty {
                        showToast(message: "Không thể tải danh sách hoạt động", type: .error)
                    }
                }
            }
            .store(in: &cancellables)
    }

    func addActivity(tripDayId: Int, activity: TripActivity, completion: @escaping (Result<TripActivity, Error>) -> Void) {
        guard networkManager.isNetworkAvailable else {
            print("🌐 No network, cannot add activity")
            showToast(message: "Vui lòng kiểm tra kết nối mạng để thêm hoạt động", type: .error)
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không có kết nối mạng"])))
            return
        }

        let newActivity = TripActivity(
            id: activity.id,
            tripDayId: tripDayId,
            startTime: activity.startTime,
            endTime: activity.endTime,
            activity: activity.activity,
            address: activity.address,
            estimatedCost: activity.estimatedCost,
            actualCost: activity.actualCost,
            note: activity.note,
            createdAt: activity.createdAt,
            updatedAt: activity.updatedAt,
            activityImages: []
        )

        activities.append(newActivity)
        showToast(message: "Đã thêm hoạt động: \(newActivity.activity)", type: .success)
        refreshTrigger = UUID()

        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/days/\(tripDayId)/activities"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ Invalid URL or Token")
            activities.removeAll { $0.id == newActivity.id }
            refreshTrigger = UUID()
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL hoặc Token không hợp lệ"])))
            return
        }

        let body: [String: Any] = [
            "activity": newActivity.activity,
            "address": newActivity.address,
            "start_time": newActivity.startTime,
            "end_time": newActivity.endTime,
            "estimated_cost": Int(newActivity.estimatedCost),
            "actual_cost": newActivity.actualCost.map { Int($0) } as Any,
            "note": newActivity.note,
            "image_ids": []
        ]

        print("📤 Sending API body: \(body)")

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            print("❌ Error creating JSON")
            activities.removeAll { $0.id == newActivity.id }
            refreshTrigger = UUID()
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Lỗi khi tạo JSON"])))
            return
        }

        let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: jsonData)
        isLoading = true
        networkManager.performRequest(request, decodeTo: TripActivityResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                self.isLoading = false
                switch completionResult {
                case .failure(let error):
                    print("❌ Error adding activity via API: \(error.localizedDescription)")
                    self.activities.removeAll { $0.id == newActivity.id }
                    self.refreshTrigger = UUID()
                    self.showToast(message: "Không thể lưu hoạt động lên server", type: .error)
                    completion(.failure(error))
                case .finished:
                    print("✅ Adding activity via API completed")
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.success, let addedActivity = response.data {
                    self.activities.removeAll { $0.id == newActivity.id }
                    self.activities.append(addedActivity)
                    self.saveToCache(activities: self.activities)
                    self.refreshTrigger = UUID()
                    self.showToast(message: "Đã lưu hoạt động: \(addedActivity.activity)", type: .success)
                    print("💾 Updated cache after adding activity: \(addedActivity.activity)")
                    completion(.success(addedActivity))
                } else {
                    self.activities.removeAll { $0.id == newActivity.id }
                    self.refreshTrigger = UUID()
                    self.showToast(message: "Không thể lưu hoạt động", type: .error)
                    completion(.failure(NSError(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: response.message ?? "Không nhận được dữ liệu hoạt động"])))
                }
            }
            .store(in: &cancellables)
    }

    func updateActivityInfo(tripDayId: Int, activity: TripActivity, completion: @escaping (Result<TripActivity, Error>) -> Void) {
        guard networkManager.isNetworkAvailable else {
            print("🌐 No network, cannot update activity")
            showToast(message: "Vui lòng kiểm tra kết nối mạng để cập nhật hoạt động", type: .error)
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không có kết nối mạng"])))
            return
        }

        let updatedActivity = TripActivity(
            id: activity.id,
            tripDayId: tripDayId,
            startTime: activity.startTime,
            endTime: activity.endTime,
            activity: activity.activity,
            address: activity.address,
            estimatedCost: activity.estimatedCost,
            actualCost: activity.actualCost,
            note: activity.note,
            createdAt: activity.createdAt,
            updatedAt: activity.updatedAt,
            activityImages: []
        )

        if let index = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[index] = updatedActivity
        } else {
            activities.append(updatedActivity)
        }
        showToast(message: "Đã cập nhật hoạt động: \(updatedActivity.activity)", type: .success)
        refreshTrigger = UUID()

        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/days/\(tripDayId)/activities/\(activity.id)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ Invalid URL or Token")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL hoặc Token không hợp lệ"])))
            return
        }

        let body: [String: Any] = [
            "activity": updatedActivity.activity,
            "address": updatedActivity.address,
            "start_time": updatedActivity.startTime,
            "end_time": updatedActivity.endTime,
            "estimated_cost": Int(updatedActivity.estimatedCost),
            "actual_cost": updatedActivity.actualCost.map { Int($0) } as Any,
            "note": updatedActivity.note,
            "image_ids": []
        ]

        print("📤 Sending API body for update: \(body)")

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            print("❌ Error creating JSON")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Lỗi khi tạo JSON"])))
            return
        }

        let request = NetworkManager.createRequest(url: url, method: "PATCH", token: token, body: jsonData)
        isLoading = true
        networkManager.performRequest(request, decodeTo: TripActivityResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                self.isLoading = false
                switch completionResult {
                case .failure(let error as NSError):
                    print("❌ Error updating activity via API: \(error.localizedDescription)")
                    if error.code == -1011 { // 403 Forbidden
                        self.showToast(message: "Bạn không có quyền cập nhật hoạt động này", type: .error)
                    } else {
                        self.showToast(message: "Không thể lưu thay đổi lên server", type: .error)
                    }
                    completion(.failure(error))
                case .finished:
                    print("✅ Updating activity via API completed")
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.success, let updatedActivity = response.data {
                    if let index = self.activities.firstIndex(where: { $0.id == updatedActivity.id }) {
                        self.activities[index] = updatedActivity
                    } else {
                        self.activities.append(updatedActivity)
                    }
                    self.saveToCache(activities: self.activities)
                    self.refreshTrigger = UUID()
                    self.showToast(message: "Đã lưu thay đổi cho hoạt động: \(updatedActivity.activity)", type: .success)
                    completion(.success(updatedActivity))
                } else {
                    self.showToast(message: "Không thể lưu thay đổi", type: .error)
                    completion(.failure(NSError(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: response.message ?? "Không nhận được dữ liệu hoạt động"])))
                }
            }
            .store(in: &cancellables)
    }

    func updateActivityImages(tripDayId: Int, activity: TripActivity, imageIds: [Int], completion: @escaping (Result<TripActivity, Error>) -> Void) {
        guard networkManager.isNetworkAvailable else {
            print("🌐 No network, cannot update activity images")
            showToast(message: "Vui lòng kiểm tra kết nối mạng để cập nhật ảnh", type: .error)
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không có kết nối mạng"])))
            return
        }

        // Lấy danh sách ảnh hiện tại từ server
        guard let imagesUrl = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/days/\(tripDayId)/activities/\(activity.id)/images"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ Invalid URL or Token for fetching images")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL hoặc Token không hợp lệ"])))
            return
        }

        let imagesRequest = NetworkManager.createRequest(url: imagesUrl, method: "GET", token: token)
        isLoading = true
        networkManager.performRequest(imagesRequest, decodeTo: ActivityImagesResponse.self)
            .flatMap { [weak self] imagesResponse -> AnyPublisher<TripActivity, Error> in
                guard let self else {
                    return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self deallocated"])).eraseToAnyPublisher()
                }

                // Lấy danh sách ID ảnh hiện tại từ server
                let existingImageIds = imagesResponse.data?.map { $0.id } ?? []
                print("📸 Existing image IDs from server: \(existingImageIds)")
                print("📸 New image IDs: \(imageIds)")
                let updatedImageIds = Array(Set(existingImageIds + imageIds))
                print("📸 Combined image IDs: \(updatedImageIds)")

                // Tạo body cho yêu cầu PATCH
                let body: [String: Any] = [
                    "activity_images": updatedImageIds
                ]
                print("📤 Sending API body for image update: \(body)")

                guard let patchUrl = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(self.tripId)/days/\(tripDayId)/activities/\(activity.id)"),
                      let patchToken = UserDefaults.standard.string(forKey: "authToken"),
                      let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
                    print("❌ Invalid URL or Token for PATCH")
                    return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL hoặc Token không hợp lệ"])).eraseToAnyPublisher()
                }

                let patchRequest = NetworkManager.createRequest(url: patchUrl, method: "PATCH", token: patchToken, body: jsonData)
                return self.networkManager.performRequest(patchRequest, decodeTo: TripActivityResponse.self)
                    .tryMap { response in  // Thay .map bằng .tryMap
                        if response.success, let updatedActivity = response.data {
                            return updatedActivity
                        } else {
                            throw NSError(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: response.message ?? "Không nhận được dữ liệu hoạt động"])
                        }
                    }
                    .eraseToAnyPublisher()
            }
            .sink { [weak self] completionResult in
                guard let self else { return }
                self.isLoading = false
                switch completionResult {
                case .failure(let error):
                    print("❌ Error updating activity images via API: \(error.localizedDescription)")
                    self.showToast(message: "Không thể lưu ảnh lên server", type: .error)
                    completion(.failure(error))
                case .finished:
                    print("✅ Updating activity images via API completed")
                }
            } receiveValue: { [weak self] updatedActivity in
                guard let self else { return }
                if let index = self.activities.firstIndex(where: { $0.id == updatedActivity.id }) {
                    self.activities[index] = updatedActivity
                } else {
                    self.activities.append(updatedActivity)
                }
                self.saveToCache(activities: self.activities)
                self.refreshTrigger = UUID()
                self.showToast(message: "Đã cập nhật ảnh cho hoạt động: \(updatedActivity.activity)", type: .success)
                completion(.success(updatedActivity))
            }
            .store(in: &cancellables)
    }

    func deleteActivity(activityId: Int, tripDayId: Int, completion: @escaping () -> Void) {
        guard networkManager.isNetworkAvailable else {
            print("🌐 No network, cannot delete activity")
            showToast(message: "Vui lòng kiểm tra kết nối mạng để xóa hoạt động", type: .error)
            completion()
            return
        }

        activities.removeAll { $0.id == activityId }
        showToast(message: "Đã xóa hoạt động", type: .success)
        refreshTrigger = UUID()

        guard let token = UserDefaults.standard.string(forKey: "authToken"),
              let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/days/\(tripDayId)/activities/\(activityId)") else {
            print("❌ Invalid URL or Token")
            showToast(message: "Đã xảy ra lỗi, vui lòng thử lại", type: .error)
            completion()
            return
        }

        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
        isLoading = true

        networkManager.performRequest(request, decodeTo: BaseResponse.self)
            .sink { [weak self] result in
                guard let self else { return }
                self.isLoading = false
                switch result {
                case .failure(let error as NSError):
                    print("❌ Error deleting activity: \(error.localizedDescription)")
                    if error.code == -1011 { // 403 Forbidden
                        self.showToast(message: "Bạn không có quyền xóa hoạt động này", type: .error)
                    } else {
                        self.showToast(message: "Không thể xóa hoạt động", type: .error)
                    }
                    self.fetchActivities(tripDayId: tripDayId)
                    completion()
                case .finished:
                    print("✅ Deleting activity completed")
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.success {
                    self.saveToCache(activities: self.activities)
                    self.showToast(message: "Đã xóa hoạt động thành công", type: .success)
                    completion()
                } else {
                    self.showToast(message: "Không thể xóa hoạt động", type: .error)
                    self.fetchActivities(tripDayId: tripDayId)
                    completion()
                }
            }
            .store(in: &cancellables)
    }
    

    func calculateTotalCosts(for tripDayId: Int) -> (totalActualCost: Double, totalEstimatedCost: Double) {
        let filteredActivities = activities.filter { $0.tripDayId == tripDayId }
        let totalActualCost = filteredActivities.reduce(0.0) { $0 + ($1.actualCost ?? 0.0) }
        let totalEstimatedCost = filteredActivities.reduce(0.0) { $0 + $1.estimatedCost }
        print("💰 Total actualCost for tripDayId \(tripDayId): \(totalActualCost), Total estimatedCost: \(totalEstimatedCost)")
        return (totalActualCost, totalEstimatedCost)
    }

    private func saveToCache(activities: [TripActivity]) {
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ActivityEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tripId == %d", tripId)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            for activity in activities {
                let entity = activity.toEntity(context: context)
                entity.tripId = Int64(tripId)
            }
            try context.save()
            print("💾 Cached activities for tripId=\(tripId) with \(activities.count) activities")
        } catch {
            print("❌ Error saving to Core Data: \(error.localizedDescription)")
            showToast(message: "Không thể lưu dữ liệu vào bộ nhớ", type: .error)
        }
    }

    func loadFromCache() -> [TripActivity]? {
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<ActivityEntity> = ActivityEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tripId == %d", tripId)
        do {
            let entities = try context.fetch(fetchRequest)
            let activities = entities.map { TripActivity(from: $0) }
            print("📂 Loaded cache with \(activities.count) activities for tripId=\(tripId)")
            return activities.isEmpty ? nil : activities
        } catch {
            print("❌ Error loading cache: \(error.localizedDescription)")
            showToast(message: "Không thể tải dữ liệu từ bộ nhớ", type: .error)
            return nil
        }
    }

    private func clearCache() {
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ActivityEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tripId == %d", tripId)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            coreDataStack.saveContext()
            print("🗑️ Cleared cache for activities for tripId=\(tripId)")
        } catch {
            print("❌ Error clearing cache: \(error.localizedDescription)")
        }
    }

    func showToast(message: String, type: ToastType) {
        print("📢 Setting toast: \(message) with type: \(type)")
        DispatchQueue.main.async {
            self.toastMessage = message
            self.toastType = type
            self.showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                print("📢 Hiding toast")
                self.showToast = false
                self.toastMessage = nil
                self.toastType = nil
            }
        }
    }
    
}
