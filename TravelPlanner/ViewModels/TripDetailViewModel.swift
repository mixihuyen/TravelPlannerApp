import Foundation
import Combine
import SwiftUI

class TripDetailViewModel: ObservableObject {
    let trip: TripModel
    @Published var tripDays: [Date] = []
    @Published var tripDaysData: [TripDay] = []
    @Published var isLoading = false
    private var cancellables = Set<AnyCancellable>()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    init(trip: TripModel) {
        self.trip = trip
        fetchTripDays()
    }
    
    private func fetchTripDays() {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("Không tìm thấy token trong UserDefaults")
            return
        }
        
        guard let url = URL(string: "https://travel-api-79ct.onrender.com/api/v1/trips/\(trip.id)/days") else {
            print("URL không hợp lệ")
            return
        }
        isLoading = true
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true
        
        let session = URLSession(configuration: config)
        session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Response JSON: \(jsonString)")
                }
                
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data), !errorResponse.success {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
                }
                
                return data
            }
            .decode(type: TripDayResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                switch completion {
                case .failure(let error):
                    print(" Lỗi khi fetch trip days: \(error.localizedDescription)")
                case .finished:
                    print(" Fetch trip days thành công")
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                if let tripDays = response.data?.tripDays {
                    self.tripDaysData = tripDays
                    self.tripDays = tripDays.compactMap { self.dateFormatter.date(from: $0.day) }
                } else {
                    print("Không có dữ liệu trip days")
                }
            }
            .store(in: &cancellables)
    }
    
    
    
    func activities(for date: Date) -> [TripActivity] {
        let selectedDateString = dateFormatter.string(from: date)
        if let tripDay = tripDaysData.first(where: { $0.day == selectedDateString }) {
            return tripDay.activities
        }
        return []
    }
    
    
    
}
