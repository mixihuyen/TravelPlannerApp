import Foundation
import Combine

class ParticipantViewModel: ObservableObject {
    @Published var participants: [Participant] = []
    @Published var searchResults: [User] = []
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    @Published var isLoading: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager()
    
    private var token: String? {
        UserDefaults.standard.string(forKey: "authToken")
    }

    // MARK: - Fetch Participants
    func fetchParticipants(tripId: Int, forceRefresh: Bool = false, completionHandler: (() -> Void)? = nil) {
        if !forceRefresh, let cachedParticipants = loadFromCache(tripId: tripId) {
            participants = cachedParticipants
            completionHandler?()
            return
        }

        guard let token, !token.isEmpty,
              let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/participants") else {
            showToast(message: "Invalid token or URL")
            completionHandler?()
            return
        }

        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: ParticipantResponse.self)
            .sink { [weak self] completion in
                self?.isLoading = false
                self?.handleCompletion(completion)
                completionHandler?()
            } receiveValue: { [weak self] response in
                guard response.success, let participants = response.data?.participants else {
                    self?.showToast(message: response.message ?? "Failed to load participants")
                    return
                }
                self?.participants = participants
                self?.saveToCache(participants: participants, tripId: tripId)
            }
            .store(in: &cancellables)
    }
    // MARK: - Search Users
    func searchUsers(query: String) {
        guard let token, !token.isEmpty,
              let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(APIConfig.baseURL)/users?username=\(encodedQuery)") else {
            searchResults = []
            return
        }

        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        networkManager.performRequest(request, decodeTo: UserSearchResponse.self)
            .sink { [weak self] completion in
                self?.handleCompletion(completion)
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
                self?.fetchParticipants(tripId: tripId, forceRefresh: true, completionHandler: completionHandler)
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
        guard let token, !token.isEmpty,
              let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/participants/\(tripParticipantId)") else {
            print("❌ Invalid token or URL")
            showToast(message: "Invalid token or URL")
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
                    self?.showToast(message: "Lỗi khi xóa thành viên: \(error.localizedDescription)")
                    completionHandler?()
                case .finished:
                    print("✅ Request completed")
                    completionHandler?()
                }
            } receiveValue: { [weak self] response in
                guard let self else {
                    print("❌ Self deallocated during removeParticipant")
                    completionHandler?()
                    return
                }
                if response.success {
                    // Tìm userId của participant bị xóa
                    if let participant = self.participants.first(where: { $0.id == tripParticipantId }) {
                        let userId = participant.user.id
                        //print("👥 Removing participant with userId=\(userId) (tripParticipantId=\(tripParticipantId))")
                        // Xóa participant khỏi danh sách cục bộ
                        self.participants.removeAll { $0.id == tripParticipantId }
                        self.saveToCache(participants: self.participants, tripId: tripId)
                        //print("👥 Updated participants count: \(self.participants.count)")
                        self.showToast(message: response.message ?? "Đã xóa thành viên thành công!")
                        
                        // Gọi unassignItemsForUser để bỏ gán các vật dụng
                        packingListViewModel?.unassignItemsForUser(userId: userId) {
                            //print("✅ Hoàn tất bỏ gán vật dụng cho userId=\(userId)")
                            // Xóa cache và làm mới packing list
                            UserDefaults.standard.removeObject(forKey: "packing_list_cache_\(tripId)")
                            //print("🗑️ Đã xóa cache packing list cho tripId=\(tripId)")
                            packingListViewModel?.fetchPackingList {
                               // print("✅ Đã làm mới packing list từ API sau khi xóa participant")
                                completionHandler?()
                            }
                        }
                    } else {
                        //print("⚠️ Participant with tripParticipantId=\(tripParticipantId) not found")
                        self.showToast(message: "Không tìm thấy thành viên để xóa")
                        completionHandler?()
                    }
                } else {
                    //print("❌ Failed to remove participant: \(response.message ?? "Unknown error")")
                    self.showToast(message: response.message ?? "Lỗi khi xóa thành viên")
                    completionHandler?()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Refresh Participants
    func refreshParticipants(tripId: Int, completionHandler: (() -> Void)? = nil) {
        UserDefaults.standard.removeObject(forKey: "participants_\(tripId)")
        UserDefaults.standard.removeObject(forKey: "participants_cache_date_\(tripId)")
        fetchParticipants(tripId: tripId, forceRefresh: true, completionHandler: completionHandler)
    }

    // MARK: - Private Methods
    private func saveToCache(participants: [Participant], tripId: Int) {
        guard let data = try? JSONEncoder().encode(participants) else { return }
        UserDefaults.standard.set(data, forKey: "participants_\(tripId)")
        UserDefaults.standard.set(Date(), forKey: "participants_cache_date_\(tripId)")
    }

    private func loadFromCache(tripId: Int) -> [Participant]? {
        guard let cacheDate = UserDefaults.standard.object(forKey: "participants_cache_date_\(tripId)") as? Date,
              Date().timeIntervalSince(cacheDate) < 3600,
              let data = UserDefaults.standard.data(forKey: "participants_\(tripId)"),
              let participants = try? JSONDecoder().decode([Participant].self, from: data) else {
            return nil
        }
        return participants
    }

    private func handleCompletion(_ completion: Subscribers.Completion<Error>) {
        if case .failure(let error) = completion {
            showToast(message: error.localizedDescription)
        }
    }

    private func showToast(message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showToast = false
            self?.toastMessage = nil
        }
    }
}
