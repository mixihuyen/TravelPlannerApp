import Foundation
import Combine
import Network
import CoreImage.CIFilterBuiltins
import UIKit

class ParticipantViewModel: ObservableObject {
    @Published var participants: [Participant] = []
    @Published var searchResults: [UserInformation] = []
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    @Published var isLoading: Bool = false
    @Published var toastType: ToastType?
    
    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager.shared
    private let cacheKeyPrefix = "participants_"
    private let cacheTTL: TimeInterval = 300 // 5 phút
    static var ramCache: [Int: (participants: [Participant], timestamp: Date)] = [:]
    private let networkMonitor = NWPathMonitor()
    private var isOnline: Bool = true
    
    private var token: String? {
        UserDefaults.standard.string(forKey: "authToken")
    }
    
    private var currentUserId: Int? {
        UserDefaults.standard.integer(forKey: "userId")
    }
    
    init() {
       
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
    }
    func clearCacheOnLogout() {
        participants = []
        searchResults = []
        print("🗑️ Đã xóa cache của ParticipantViewModel")
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
    
    // MARK: - QR Code Generation
        func generateQRCode(for tripId: Int) -> UIImage {
            let deepLink = "myapp://trip/join?tripId=\(tripId)"
            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data(deepLink.utf8)
            
            if let outputImage = filter.outputImage {
                let context = CIContext()
                if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
            return UIImage(systemName: "qrcode") ?? UIImage()
        }
        
        // MARK: - Deep Link Generation
        func copyDeepLink(tripId: Int) {
            let deepLink = "myapp://trip/join?tripId=\(tripId)"
            UIPasteboard.general.string = deepLink
            print("📋 Copied deep link: \(deepLink)")
        }
        
        // MARK: - Join Trip
        func joinTrip(tripId: Int, completionHandler: (() -> Void)? = nil) {
            guard let token = token, !token.isEmpty,
                  let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/participants/join") else {
                print("❌ Invalid token or URL for joining trip")
                showToast(message: "Thông tin không hợp lệ", type: .error)
                completionHandler?()
                return
            }

            let request = NetworkManager.createRequest(url: url, method: "POST", token: token)
            isLoading = true
            networkManager.performRequest(request, decodeTo: ParticipantResponse.self)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    self?.isLoading = false
                    switch completion {
                    case .failure(let error):
                        print("❌ Error joining trip: \(error.localizedDescription)")
                        let errorMessage = (error as? URLError)?.code == .userAuthenticationRequired
                            ? "Bạn không có quyền tham gia chuyến đi"
                            : "Lỗi khi tham gia chuyến đi: \(error.localizedDescription)"
                        self?.showToast(message: errorMessage, type: .error)
                        completionHandler?()
                    case .finished:
                        print("✅ Successfully completed join trip request")
                    }
                } receiveValue: { [weak self] response in
                    guard let self else {
                        print("❌ Self deallocated during joinTrip")
                        completionHandler?()
                        return
                    }
                    if response.success, response.data != nil {
                        self.showToast(message: response.message ?? "Tham gia chuyến đi thành công!", type: .success)
                        self.fetchParticipants(tripId: tripId, forceRefresh: true, completion: completionHandler)
                    } else {
                        print("❌ Failed to join trip: \(response.message ?? "Unknown error")")
                        self.showToast(message: response.message ?? "Lỗi khi tham gia chuyến đi", type: .error)
                        completionHandler?()
                    }
                }
                .store(in: &cancellables)
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
            showToast(message: "Không có mạng, sử dụng dữ liệu cũ", type: .error)
            completion?()
        }
    }
    
    private func fetchFromAPI(tripId: Int, completion: (() -> Void)? = nil) {
        guard let token,
              let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/participants") else {
            showToast(message: "Invalid token or URL", type: .error)
            completion?()
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: ParticipantsResponse.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completionResult in
                self?.isLoading = false
                self?.handleCompletion(completionResult)
                completion?()
            } receiveValue: { [weak self] response in
                guard response.success, let newParticipants = response.data else {
                    self?.showToast(message: response.message ?? "Failed to load participants", type: .error)
                    return
                }
                // So sánh dữ liệu mới với RAM cache
                if let (currentParticipants, _) = Self.ramCache[tripId] {
                    let areEqual = currentParticipants.count == newParticipants.count &&
                        currentParticipants.enumerated().allSatisfy { (index, participant) in
                            let newParticipant = newParticipants[index]
                            return participant.id == newParticipant.id &&
                                   participant.updatedAt == newParticipant.updatedAt &&
                                   participant.userInformation.id == newParticipant.userInformation.id &&
                                   participant.userInformation.username == newParticipant.userInformation.username
                        }
                    if areEqual {
                        print("✅ Dữ liệu API giống RAM cache, không cập nhật UI")
                        return
                    }
                }
                self?.updateParticipants(with: newParticipants)
                self?.participants.forEach { print("👤 Participant ID: \($0.id) - User: \($0.userInformation.username ?? "N/A")") }
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
              let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/participants/addMember") else {
            showToast(message: "Invalid token or URL", type: .error)
            return
        }

        let body = ["user_id": userId]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            showToast(message: "Failed to encode data", type: .error)
            return
        }

        let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: jsonData)
        isLoading = true
        networkManager.performRequest(request, decodeTo: ParticipantResponse.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                self?.handleCompletion(completion)
            } receiveValue: { [weak self] response in
                guard response.success, response.data != nil else {
                    self?.showToast(message: response.message?.contains("already") ?? false
                        ? "Người dùng đã có trong chuyến đi"
                        : response.message ?? "Thêm thành viên thất bại", type: .error)
                    return
                }
                self?.showToast(message: response.message ?? "Thêm thành viên thành công!", type: .success)
                self?.fetchParticipants(tripId: tripId, forceRefresh: true, completion: completionHandler)
            }
            .store(in: &cancellables)
    }
    
    func addMultipleParticipants(tripId: Int, users: [UserInformation], completionHandler: @escaping (Int) -> Void) {
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
            showToast(message: "Thông tin không hợp lệ", type: .error)
            completionHandler?()
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: EmptyResponse.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    print("❌ Error removing participant: \(error.localizedDescription)")
                    let errorMessage = (error as? URLError)?.code == .userAuthenticationRequired
                    ? "Bạn không có quyền xóa thành viên này"
                    : "Lỗi khi xóa thành viên: \(error.localizedDescription)"
                    self?.showToast(message: errorMessage, type: .error)
                    completionHandler?()
                case .finished:
                    print("✅ Successfully removed participant")
                    if let participant = self?.participants.first(where: { $0.id == tripParticipantId }) {
                        let userId = participant.userInformation.id
                        self?.participants.removeAll { $0.id == tripParticipantId }
                        self?.saveToCache(participants: self?.participants ?? [], tripId: tripId)
                        self?.showToast(message: "Đã xóa thành viên thành công!", type: .success)
                        
                        packingListViewModel?.unassignItemsForUser(userId: userId) {
                            UserDefaults.standard.removeObject(forKey: "packing_list_cache_\(tripId)")
                            packingListViewModel?.fetchPackingList {
                                print("✅ Refreshed packing list after removing participant")
                                completionHandler?()
                            }
                        }
                    } else {
                        print("⚠️ Participant with tripParticipantId=\(tripParticipantId) not found")
                        self?.showToast(message: "Không tìm thấy thành viên để xóa", type: .error)
                        completionHandler?()
                    }
                }
            } receiveValue: { _ in
                // Không cần xử lý giá trị trả về vì EmptyResponse không chứa dữ liệu
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Leave Trip
    func leaveTrip(tripId: Int, packingListViewModel: PackingListViewModel? = nil, completionHandler: (() -> Void)? = nil) {
        guard let token = token, !token.isEmpty,
              let userId = currentUserId,
              let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/participants/leave") else {
            print("❌ Invalid token or URL")
            showToast(message: "Không thể rời nhóm: Thông tin không hợp lệ", type: .error)
            completionHandler?()
            return
        }

        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: BaseResponse.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    print("❌ Error leaving trip: \(error.localizedDescription)")
                    let errorMessage = (error as? URLError)?.code == .userAuthenticationRequired
                        ? "Bạn không có quyền rời nhóm"
                        : "Lỗi khi rời nhóm: \(error.localizedDescription)"
                    self?.showToast(message: errorMessage, type: .error)
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
                    self.participants.removeAll { $0.userInformation.id == userId }
                    self.saveToCache(participants: self.participants, tripId: tripId)
                    self.showToast(message: response.message ?? "Đã rời nhóm thành công!", type: .success)
                    
                    packingListViewModel?.unassignItemsForUser(userId: userId) {
                        UserDefaults.standard.removeObject(forKey: "packing_list_cache_\(tripId)")
                        packingListViewModel?.fetchPackingList {
                            print("✅ Refreshed packing list after leaving trip")
                            completionHandler?()
                            NotificationCenter.default.post(name: .didLeaveTrip, object: nil, userInfo: ["tripId": tripId])
                        }
                    }
                } else {
                    print("❌ Failed to leave trip: \(response.message ?? "Unknown error")")
                    self.showToast(message: response.message ?? "Lỗi khi rời nhóm", type: .error)
                    completionHandler?()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Edit Participant Role
        func editParticipantRole(tripId: Int, participantId: Int, newRole: String, completionHandler: (() -> Void)? = nil) {
            guard let token = token, !token.isEmpty,
                  let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/participants/\(participantId)") else {
                print("❌ Invalid token or URL for editing role")
                showToast(message: "Thông tin không hợp lệ", type: .error)
                completionHandler?()
                return
            }

            let body = ["role": newRole]
            guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
                print("❌ Failed to encode role data")
                showToast(message: "Lỗi khi chuẩn bị dữ liệu", type: .error)
                completionHandler?()
                return
            }

            let request = NetworkManager.createRequest(url: url, method: "PATCH", token: token, body: jsonData)
            isLoading = true
            networkManager.performRequest(request, decodeTo: ParticipantResponse.self)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    self?.isLoading = false
                    switch completion {
                    case .failure(let error):
                        print("❌ Error editing participant role: \(error.localizedDescription)")
                        let errorMessage = (error as? URLError)?.code == .userAuthenticationRequired
                            ? "Bạn không có quyền chỉnh sửa vai trò"
                            : "Lỗi khi chỉnh sửa vai trò: \(error.localizedDescription)"
                        self?.showToast(message: errorMessage, type: .error)
                        completionHandler?()
                    case .finished:
                        print("✅ Successfully completed role edit request")
                    }
                } receiveValue: { [weak self] response in
                    guard let self else {
                        print("❌ Self deallocated during editParticipantRole")
                        completionHandler?()
                        return
                    }
                    if response.success, let updatedParticipant = response.data {
                        // Cập nhật participant trong danh sách
                        if let index = self.participants.firstIndex(where: { $0.id == participantId }) {
                            var updated = self.participants[index]
                            updated.role = updatedParticipant.role
                            updated.updatedAt = updatedParticipant.updatedAt
                            self.participants[index] = updated
                            self.saveToCache(participants: self.participants, tripId: tripId)
                            print("✅ Updated participant role to \(newRole) for participant ID: \(participantId)")
                            self.showToast(message: response.message ?? "Cập nhật vai trò thành công!", type: .success)
                        } else {
                            print("⚠️ Participant with ID \(participantId) not found")
                            self.showToast(message: "Không tìm thấy thành viên để cập nhật", type: .error)
                        }
                    } else {
                        print("❌ Failed to edit role: \(response.message ?? "Unknown error")")
                        self.showToast(message: response.message ?? "Lỗi khi cập nhật vai trò", type: .error)
                    }
                    completionHandler?()
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
            showToast(message: error.localizedDescription, type: .error)
        }
    }
    
    func showToast(message: String, type: ToastType) {
        print("📢 Đặt toast: \(message) với type: \(type)")
        DispatchQueue.main.async {
            self.toastMessage = message
            self.toastType = type
            self.showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                print("📢 Ẩn toast")
                self.showToast = false
                self.toastMessage = nil
                self.toastType = nil
            }
        }
    }
}
extension Notification.Name {
    static let didLeaveTrip = Notification.Name("didLeaveTrip")
}
