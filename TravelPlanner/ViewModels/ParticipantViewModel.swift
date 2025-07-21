import Foundation
import Combine

class ParticipantViewModel: ObservableObject {
    @Published var participants: [Participant] = []
    private var cancellables = Set<AnyCancellable>()
    
    private var token: String? {
        UserDefaults.standard.string(forKey: "authToken")
    }

    func fetchParticipants(tripId: Int) {
        if let cachedData = loadFromCache(tripId: tripId) {
            self.participants = cachedData
            return
        }
        
        guard let token = token else {
            print("Không có token, không thể gọi API.")
            return
        }
        
        guard let url = URL(string: "https://travel-api-79ct.onrender.com/api/v1/trips/\(tripId)/participants") else {
            print("URL không hợp lệ")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true
        
        let session = URLSession(configuration: config)
        
        session.dataTaskPublisher(for: request)
            .map { $0.data }
            .decode(type: ParticipantResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .failure(let error):
                    print("Lỗi khi fetch participants: \(error.localizedDescription)")
                case .finished:
                    print("Fetch participants thành công")
                }
            } receiveValue: { [weak self] response in
                if response.success == false {
                    print("API trả về lỗi: \(response.message ?? "Không rõ lỗi")")
                    return
                }

                guard let data = response.data else {
                    print("Không có dữ liệu participant")
                    return
                }

                self?.participants = data.participants
                self?.saveToCache(participants: data.participants, tripId: tripId)
            }
            .store(in: &cancellables)
    }
    
    private func saveToCache(participants: [Participant], tripId: Int) {
        do {
            let data = try JSONEncoder().encode(participants)
            UserDefaults.standard.set(data, forKey: "participants_\(tripId)")
            UserDefaults.standard.set(Date(), forKey: "participants_cache_date_\(tripId)")
        } catch {
            print("Lỗi khi lưu cache: \(error.localizedDescription)")
        }
    }
    
    private func loadFromCache(tripId: Int) -> [Participant]? {
        guard let cacheDate = UserDefaults.standard.object(forKey: "participants_cache_date_\(tripId)") as? Date,
              Date().timeIntervalSince(cacheDate) < 3600,
              let data = UserDefaults.standard.data(forKey: "participants_\(tripId)") else {
            return nil
        }
        
        do {
            let participants = try JSONDecoder().decode([Participant].self, from: data)
            return participants
        } catch {
            print("Lỗi khi đọc cache: \(error.localizedDescription)")
            return nil
        }
    }
}
