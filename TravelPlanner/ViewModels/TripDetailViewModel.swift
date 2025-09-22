import Foundation
import Combine
import SwiftUI
import Network
import CoreData
 
class TripDetailViewModel: ObservableObject {
    let tripId: Int
    @Published var isLoading: Bool = false
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    @Published var refreshTrigger: UUID = UUID()
    @Published var toastType: ToastType?
    @Published var tripDays: [TripDay] = []
    private var cancellables = Set<AnyCancellable>()
    private var networkManager: NetworkManager
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private let cacheExpirationSeconds: TimeInterval = 1800 // 30 minutes
    private let coreDataStack = CoreDataStack.shared

    init(tripId: Int, networkManager: NetworkManager = NetworkManager()) {
        self.tripId = tripId
        self.networkManager = networkManager
        print("🚀 Initializing TripDetailViewModel for tripId=\(tripId)")
        if !loadFromCache().isEmpty {
            self.tripDays = loadFromCache()
            self.refreshTrigger = UUID()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.fetchTripDays(forceRefresh: true)
            }
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLogout),
            name: .didLogout,
            object: nil
        )
    }

    @objc private func handleLogout() {
        clearCacheOnLogout()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .didLogout, object: nil)
        print("🗑️ TripDetailViewModel deallocated for tripId=\(tripId)")
    }

    func clearCacheOnLogout() {
        clearCache()
        print("🗑️ Cleared cache for TripDetailViewModel for tripId=\(tripId)")
    }

    func fetchTripDays(completion: (() -> Void)? = nil, forceRefresh: Bool = false) {
        print("📡 Starting fetchTripDays, forceRefresh=\(forceRefresh), network=\(networkManager.isNetworkAvailable)")
        if !forceRefresh {
            let cachedTripDays = loadFromCache()
            if !cachedTripDays.isEmpty {
                print("📂 Using cache with \(cachedTripDays.count) days, activities: \(cachedTripDays.flatMap { $0.activities ?? [] }.count)")
                self.tripDays = cachedTripDays
                self.refreshTrigger = UUID()
                if !networkManager.isNetworkAvailable {
                    showToast(message: "Không có kết nối mạng, hiển thị dữ liệu từ bộ nhớ", type: .error)
                    completion?()
                    return
                }
                // Check API for updates if needed
                fetchFromAPI(completion: completion)
                return
            }
        } else {
            print("🗑️ Clearing cache due to forceRefresh")
            clearCache()
        }
        
        fetchFromAPI(completion: completion)
    }

    private func fetchFromAPI(completion: (() -> Void)? = nil) {
        guard networkManager.isNetworkAvailable else {
            print("🌐 No network, displaying data from cache")
            let cachedTripDays = loadFromCache()
            if !cachedTripDays.isEmpty {
                self.tripDays = cachedTripDays
                self.refreshTrigger = UUID()
                showToast(message: "Không có kết nối mạng, hiển thị dữ liệu từ bộ nhớ", type: .error)
            } else {
                showToast(message: "Vui lòng kiểm tra kết nối mạng", type: .error)
            }
            completion?()
            return
        }

        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/days"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ Invalid URL or Token")
            isLoading = false
            showToast(message: "Đã xảy ra lỗi, vui lòng thử lại", type: .error)
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
                guard let self else { return }
                if response.success {
                    let tripDays = response.data
                    print("📡 API returned \(tripDays.count) days with \(tripDays.flatMap { $0.activities ?? [] }.count) activities")
                    self.tripDays = tripDays
                    self.saveToCache(tripDays: tripDays)
                    self.refreshTrigger = UUID()
                    print("📅 Fetch trip days successful: \(tripDays.count) days")
                } else {
                    print("⚠️ Fetch failed: \(response.message ?? "Unknown error")")
                    self.showToast(message: "Không thể tải danh sách ngày", type: .error)
                }
                completion?()
            }
            .store(in: &cancellables)
    }

    func getTripDayId(for date: Date, completion: @escaping (Int?) -> Void) {
        let dateString = dateFormatter.string(from: date)
        let tripDays = loadFromCache()
        if let tripDay = tripDays.first(where: { $0.day == dateString }) {
            print("✅ Retrieved tripDayId: \(tripDay.id) for date: \(dateString)")
            completion(tripDay.id)
        } else {
            print("❌ No TripDay found for date: \(dateString)")
            completion(nil)
        }
    }

    func getTripDays() -> [TripDay] {
        return tripDays
    }

    func getActivities(for tripDayId: Int) -> [TripActivity] {
        return tripDays.first(where: { $0.id == tripDayId })?.activities ?? []
    }

    private func saveToCache(tripDays: [TripDay]) {
        let context = coreDataStack.context
        clearCache()
        for tripDay in tripDays {
            let entity = tripDay.toEntity(context: context)
            entity.tripId = Int32(tripId)
            print("💾 Saving TripDayEntity: id=\(entity.id), day=\(entity.day ?? "nil"), activitiesData=\(entity.activitiesData?.count ?? 0) bytes")
        }
        do {
            try context.save()
            print("💾 Cached trip days for tripId=\(tripId) with \(tripDays.count) days and \(tripDays.flatMap { $0.activities ?? [] }.count) activities")
        } catch {
            print("❌ Error saving to Core Data: \(error.localizedDescription)")
            showToast(message: "Không thể lưu dữ liệu vào bộ nhớ", type: .error)
        }
    }

    private func loadFromCache() -> [TripDay] {
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<TripDayEntity> = TripDayEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tripId == %d", tripId)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "day", ascending: true)]
        do {
            let entities = try context.fetch(fetchRequest)
            let tripDays = entities.map { TripDay(from: $0) }
            print("📂 Cache returned \(entities.count) entities: \(entities.map { "\($0.day ?? "nil") (activitiesData: \($0.activitiesData?.count ?? 0) bytes)" })")
            print("📂 Loaded cache with \(tripDays.count) days for tripId=\(tripId), sorted by day, activities: \(tripDays.flatMap { $0.activities ?? [] }.count)")
            return tripDays
        } catch {
            print("❌ Error loading cache: \(error.localizedDescription)")
            showToast(message: "Không thể tải dữ liệu từ bộ nhớ", type: .error)
            return []
        }
    }

    private func handleCompletion(_ completion: Subscribers.Completion<Error>, completionHandler: (() -> Void)? = nil) {
        switch completion {
        case .failure(let error):
            print("❌ Error fetching trip days: \(error.localizedDescription)")
            showToast(message: "Không thể tải danh sách ngày", type: .error)
        case .finished:
            print("✅ Fetch trip days completed")
        }
        completionHandler?()
    }

    private func clearCache() {
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TripDayEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tripId == %d", tripId)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            coreDataStack.saveContext()
            print("🗑️ Cleared cache for trip days for tripId=\(tripId)")
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
