import Foundation
import Combine

class ParticipantViewModel: ObservableObject {
    @Published var participants: [Participant] = []
    private var cancellables = Set<AnyCancellable>()
    
    private var token: String? {
        UserDefaults.standard.string(forKey: "authToken")
    }

    func fetchParticipants(tripId: Int) {
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
            }
            .store(in: &cancellables)
    }
}
