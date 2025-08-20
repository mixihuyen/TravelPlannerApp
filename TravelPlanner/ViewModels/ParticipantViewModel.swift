import Foundation
import Combine
import Network

class ParticipantViewModel: ObservableObject {
    @Published var participants: [Participant] = []
    @Published var searchResults: [User] = []
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    @Published var isLoading: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let networkManager: NetworkManager
    private let cacheKeyPrefix = "participants_"
    private let cacheTTL: TimeInterval = 300 // 5 phút
    private static var ramCache: [Int: (participants: [Participant], timestamp: Date)] = [:]
    private let networkMonitor = NWPathMonitor()
    private var isOnline: Bool = true
    
    private var token: String? {
        UserDefaults.standard.string(forKey: "authToken")
    }
    
    private var currentUserId: Int? {
        UserDefaults.standard.integer(forKey: "userId")
    }
    
    init(networkManager: NetworkManager = NetworkManager()) {
        self.networkManager = networkManager
        setupNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                print("🌐 Network status: \(self?.isOnline ?? false ? "Online" : "Offline")")
            }
        }
        networkMonitor.start(queue: .global())
    }
    
    // MARK: - Pull to Refresh
    func pullToRefresh(tripId: Int, completion: (() -> Void)? = nil) {
        fetchParticipants(tripId: tripId, forceRefresh: true, completion: completion)
    }
    
    // MARK: - Fetch Participants
    func fetchParticipants(tripId: Int, forceRefresh: Bool = false, completion: (() -> Void)? = nil) {
        // Ưu tiên RAM cache nếu không yêu cầu làm mới
        if !forceRefresh, let (cachedParticipants, timestamp) = Self.ramCache[tripId], isCacheValid(timestamp: timestamp) {
            participants = cachedParticipants
            completion?()
            print("📂 Loaded from RAM cache")
            // Fetch API ngầm nếu online
            if isOnline {
                fetchFromAPI(tripId: tripId, completion: completion)
            }
            return
        }
        
        // Nếu không có RAM cache, thử Disk cache
        if !forceRefresh, let diskParticipants = loadFromDiskCache(tripId: tripId) {
            participants = diskParticipants
            Self.ramCache[tripId] = (participants: diskParticipants, timestamp: Date())
            completion?()
            print("📂 Loaded from Disk cache")
            // Fetch API ngầm nếu online
            if isOnline {
                fetchFromAPI(tripId: tripId, completion: completion)
            }
            return
        }
        
        // Nếu không có cache hoặc forceRefresh, fetch API
        if isOnline {
            fetchFromAPI(tripId: tripId, completion: completion)
        } else {
            showToast(message: "Không có mạng, sử dụng dữ liệu cũ")
            completion?()
        }
    }
    
    private func fetchFromAPI(tripId: Int, completion: (() -> Void)? = nil) {
            guard let token,
                  let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/participants") else {
                showToast(message: "Invalid token or URL")
                completion?()
                return
            }
            
            let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
            isLoading = true
            networkManager.performRequest(request, decodeTo: ParticipantResponse.self)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completionResult in
                    self?.isLoading = false
                    self?.handleCompletion(completionResult)
                    completion?()
                } receiveValue: { [weak self] response in
                    guard response.success, let newParticipants = response.data?.participants else {
                        self?.showToast(message: response.message ?? "Failed to load participants")
                        return
                    }
                    // So sánh dữ liệu mới với RAM cache
                    if let (currentParticipants, _) = Self.ramCache[tripId] {
                        let areEqual = currentParticipants.count == newParticipants.count &&
                            currentParticipants.enumerated().allSatisfy { (index, participant) in
                                let newParticipant = newParticipants[index]
                                return participant.id == newParticipant.id &&
                                       participant.updatedAt == newParticipant.updatedAt &&
                                       participant.user.id == newParticipant.user.id &&
                                       participant.user.username == newParticipant.user.username
                            }
                        if areEqual {
                            print("✅ Dữ liệu API giống RAM cache, không cập nhật UI")
                            return
                        }
                    }
                    self?.updateParticipants(with: newParticipants)
                    self?.participants.forEach { print("👤 Participant ID: \($0.id) - User: \($0.user.username ?? "N/A")") }
                    self?.saveToCache(participants: self?.participants ?? [], tripId: tripId)
                }
                .store(in: &cancellables)
        }
    
    // MARK: - Search Users
    func searchUsers(query: String) {
        guard !query.isEmpty,
              let token,
              let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(APIConfig.baseURL)/users?username=\(encodedQuery)") else {
            searchResults = []
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        networkManager.performRequest(request, decodeTo: UserSearchResponse.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completionResult in
                self?.handleCompletion(completionResult)
            } receiveValue: { [weak self] response in
                self?.searchResults = response.success ? response.data ?? [] : []
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Add Participant
    func addParticipant(tripId: Int, userId: Int, completionHandler: @escaping () -> Void) {
        guard let token, !token.isEmpty,
              let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/participants") else {
            showToast(message: "Invalid token or URL")
            return
        }

        let body = ["user_id": userId]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            showToast(message: "Failed to encode data")
            return
        }

        let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: jsonData)
        networkManager.performRequest(request, decodeTo: AddParticipantResponse.self)
            .sink { [weak self] completion in
                self?.handleCompletion(completion)
            } receiveValue: { [weak self] response in
                guard response.success, response.data?.tripParticipant != nil else {
                    self?.showToast(message: response.message?.contains("already") ?? false
                        ? "User already in trip"
                        : response.message ?? "Failed to add participant")
                    return
                }
                self?.fetchParticipants(tripId: tripId, forceRefresh: true, completion: completionHandler)
            }
            .store(in: &cancellables)
    }
    
    func addMultipleParticipants(tripId: Int, users: [User], completionHandler: @escaping (Int) -> Void) {
        var successCount = 0
        let group = DispatchGroup()
        
        for user in users {
            group.enter()
            addParticipant(tripId: tripId, userId: user.id) {
                successCount += 1
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completionHandler(successCount)
        }
    }
    
    // MARK: - Remove Participant
    func removeParticipant(tripId: Int, tripParticipantId: Int, packingListViewModel: PackingListViewModel? = nil, completionHandler: (() -> Void)? = nil) {
        guard let token = token, !token.isEmpty,
              let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/participants/\(tripParticipantId)") else {
            print("❌ Invalid token or URL")
            showToast(message: "Thông tin không hợp lệ")
            completionHandler?()
            return
        }

        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: BaseResponse.self)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    print("❌ Error removing participant: \(error.localizedDescription)")
                    let errorMessage = (error as? URLError)?.code == .userAuthenticationRequired
                        ? "Bạn không có quyền xóa thành viên này"
                        : "Lỗi khi xóa thành viên: \(error.localizedDescription)"
                    self?.showToast(message: errorMessage)
                    completionHandler?()
                case .finished:
                    print("✅ Request completed")
                }
            } receiveValue: { [weak self] response in
                guard let self else {
                    print("❌ Self deallocated during removeParticipant")
                    completionHandler?()
                    return
                }
                if response.success {
                    if let participant = self.participants.first(where: { $0.id == tripParticipantId }) {
                        let userId = participant.user.id
                        self.participants.removeAll { $0.id == tripParticipantId }
                        self.saveToCache(participants: self.participants, tripId: tripId)
                        self.showToast(message: response.message ?? "Đã xóa thành viên thành công!")
                        
                        packingListViewModel?.unassignItemsForUser(userId: userId) {
                            UserDefaults.standard.removeObject(forKey: "packing_list_cache_\(tripId)")
                            packingListViewModel?.fetchPackingList {
                                print("✅ Refreshed packing list after removing participant")
                                completionHandler?()
                            }
                        }
                    } else {
                        print("⚠️ Participant with tripParticipantId=\(tripParticipantId) not found")
                        self.showToast(message: "Không tìm thấy thành viên để xóa")
                        completionHandler?()
                    }
                } else {
                    print("❌ Failed to remove participant: \(response.message ?? "Unknown error")")
                    self.showToast(message: response.message ?? "Lỗi khi xóa thành viên")
                    completionHandler?()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Leave Trip
    func leaveTrip(tripId: Int, packingListViewModel: PackingListViewModel? = nil, completionHandler: (() -> Void)? = nil) {
        guard let token = token, !token.isEmpty,
              let userId = currentUserId,
              let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/participants") else {
            print("❌ Invalid token or URL")
            showToast(message: "Không thể rời nhóm: Thông tin không hợp lệ")
            completionHandler?()
            return
        }

        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: BaseResponse.self)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    print("❌ Error leaving trip: \(error.localizedDescription)")
                    let errorMessage = (error as? URLError)?.code == .userAuthenticationRequired
                        ? "Bạn không có quyền rời nhóm"
                        : "Lỗi khi rời nhóm: \(error.localizedDescription)"
                    self?.showToast(message: errorMessage)
                    completionHandler?()
                case .finished:
                    print("✅ Successfully completed request")
                }
            } receiveValue: { [weak self] response in
                guard let self else {
                    print("❌ Self deallocated during leaveTrip")
                    completionHandler?()
                    return
                }
                if response.success {
                    self.participants.removeAll { $0.user.id == userId }
                    self.saveToCache(participants: self.participants, tripId: tripId)
                    self.showToast(message: response.message ?? "Đã rời nhóm thành công!")
                    
                    packingListViewModel?.unassignItemsForUser(userId: userId) {
                        UserDefaults.standard.removeObject(forKey: "packing_list_cache_\(tripId)")
                        packingListViewModel?.fetchPackingList {
                            print("✅ Refreshed packing list after leaving trip")
                            completionHandler?()
                        }
                    }
                } else {
                    print("❌ Failed to leave trip: \(response.message ?? "Unknown error")")
                    self.showToast(message: response.message ?? "Lỗi khi rời nhóm")
                    completionHandler?()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Refresh Participants
    func refreshParticipants(tripId: Int, completion: (() -> Void)? = nil) {
        fetchParticipants(tripId: tripId, forceRefresh: true, completion: completion)
    }
    
    // MARK: - Check App Activity
    func checkActivityAndRefresh(tripId: Int, completion: (() -> Void)? = nil) {
        if let (_, timestamp) = Self.ramCache[tripId], isCacheValid(timestamp: timestamp) {
            print("✅ Cache still valid, using RAM cache")
            participants = Self.ramCache[tripId]?.participants ?? []
            completion?()
        } else {
            fetchParticipants(tripId: tripId, forceRefresh: isOnline, completion: completion)
        }
    }
    
    // MARK: - Private Methods
    private func isCacheValid(timestamp: Date) -> Bool {
        return Date().timeIntervalSince(timestamp) <= cacheTTL
    }
    
    private func updateParticipants(with newParticipants: [Participant]) {
        let currentIds = Set(participants.map { $0.id })
        let newIds = Set(newParticipants.map { $0.id })
        
        participants.removeAll { !newIds.contains($0.id) }
        
        for newParticipant in newParticipants {
            if let index = participants.firstIndex(where: { $0.id == newParticipant.id }) {
                if participants[index].updatedAt != newParticipant.updatedAt {
                    print("🔄 Updated participant ID: \(newParticipant.id)")
                    participants[index] = newParticipant
                }
            } else {
                print("➕ Added new participant ID: \(newParticipant.id)")
                participants.append(newParticipant)
            }
        }
        
        participants.sort { $0.id < $1.id }
    }
    
    private func saveToCache(participants: [Participant], tripId: Int) {
        // Lưu vào RAM cache
        Self.ramCache[tripId] = (participants: participants, timestamp: Date())
        print("💾 Saved to RAM cache for trip \(tripId)")
        
        // Lưu vào Disk cache
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(participants)
            UserDefaults.standard.set(data, forKey: "\(cacheKeyPrefix)\(tripId)")
            print("💾 Saved to Disk cache for trip \(tripId)")
        } catch {
            print("❌ Error saving to Disk cache: \(error.localizedDescription)")
        }
    }
    
    private func loadFromDiskCache(tripId: Int) -> [Participant]? {
        guard let data = UserDefaults.standard.data(forKey: "\(cacheKeyPrefix)\(tripId)") else {
            print("ℹ️ No Disk cache data found for trip \(tripId)")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let participants = try decoder.decode([Participant].self, from: data)
            print("✅ Loaded \(participants.count) participants from Disk cache")
            return participants
        } catch {
            print("❌ Error loading Disk cache: \(error.localizedDescription)")
            UserDefaults.standard.removeObject(forKey: "\(cacheKeyPrefix)\(tripId)")
            return nil
        }
    }
    
    private func handleCompletion(_ completion: Subscribers.Completion<Error>) {
        if case .failure(let error) = completion {
            showToast(message: error.localizedDescription)
        }
    }
    
    private func showToast(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.toastMessage = message
            self?.showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self?.showToast = false
                self?.toastMessage = nil
            }
        }
    }
}
