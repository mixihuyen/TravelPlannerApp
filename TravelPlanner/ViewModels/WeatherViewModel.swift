import Foundation
import Combine

struct WeatherData: Codable {
    let maxTemp: Int
    let minTemp: Int
    let condition: String
}

struct LocationSuggestion: Codable, Identifiable {
    let id: Int
    let name: String
    let region: String
    let country: String
    let lat: Double
    let lon: Double
}

class WeatherViewModel: ObservableObject {
    @Published var weatherData: WeatherData?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var locationSuggestions: [LocationSuggestion] = []
    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager()
    public var location: String
    public var date: Date
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    init(location: String, date: Date) {
            self.location = location
            self.date = date
            if NetworkManager.isConnected() {
                fetchWeather() // Gọi fetchWeather ngay khi khởi tạo nếu có mạng
            } else {
                self.errorMessage = "Không có kết nối mạng"
                print("🌐 Mất kết nối mạng, không thể lấy dữ liệu thời tiết")
            }
        }
    
    func fetchWeather() {
        guard NetworkManager.isConnected() else {
            self.errorMessage = "Không có kết nối mạng"
            self.weatherData = nil
            print("🌐 Mất kết nối mạng, không thể lấy dữ liệu thời tiết")
            return
        }
        
        let dateString = dateFormatter.string(from: date)
        let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "http://api.weatherapi.com/v1/forecast.json?key=\(APIConfig.weatherAPI)&q=\(encodedLocation)&dt=\(dateString)&days=1") else {
            self.errorMessage = "URL không hợp lệ"
            self.weatherData = nil
            print("❌ URL không hợp lệ: \(location), \(dateString)")
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "GET", token: "")
        isLoading = true
        
        networkManager.performRequest(request, decodeTo: WeatherResponse.self)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    print("❌ Lỗi khi lấy dữ liệu thời tiết: \(error.localizedDescription)")
                    self?.errorMessage = "Lỗi khi tải dữ liệu thời tiết"
                    self?.weatherData = nil
                case .finished:
                    print("✅ Lấy dữ liệu thời tiết thành công")
                }
            } receiveValue: { [weak self] response in
                guard let self = self, let forecastDay = response.forecast.forecastday.first else {
                    self?.errorMessage = "Không có dữ liệu dự báo"
                    self?.weatherData = nil
                    print("⚠️ Không có dữ liệu dự báo cho \(self?.location ?? "") ngày \(dateString)")
                    return
                }
                
                let weather = WeatherData(
                    maxTemp: Int(forecastDay.day.maxtemp_c),
                    minTemp: Int(forecastDay.day.mintemp_c),
                    condition: forecastDay.day.condition.text
                )
                
                self.weatherData = weather
                print("🌤️ Đã lấy dữ liệu thời tiết: \(weather.maxTemp)°C / \(weather.minTemp)°C, \(weather.condition)")
            }
            .store(in: &cancellables)
    }
    
    func searchLocations(query: String) {
        guard !query.isEmpty, NetworkManager.isConnected() else {
            self.locationSuggestions = []
            print("🌐 Không có mạng hoặc query rỗng")
            return
        }
        
        guard let url = URL(string: "http://api.weatherapi.com/v1/search.json?key=\(APIConfig.weatherAPI)&q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            self.locationSuggestions = []
            print("❌ URL tìm kiếm không hợp lệ: \(query)")
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "GET", token: "")
        
        networkManager.performRequest(request, decodeTo: [LocationSuggestion].self)
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    print("❌ Lỗi khi tìm kiếm địa điểm: \(error.localizedDescription)")
                    self?.locationSuggestions = []
                case .finished:
                    print("✅ Tìm kiếm địa điểm thành công")
                }
            } receiveValue: { [weak self] suggestions in
                self?.locationSuggestions = suggestions
                print("📍 Nhận được \(suggestions.count) gợi ý địa điểm: \(suggestions.map { $0.name })")
            }
            .store(in: &cancellables)
    }
    
    func updateLocation(_ newLocation: String) {
            self.location = newLocation
            self.weatherData = nil // Xóa dữ liệu cũ khi thay đổi location
            fetchWeather()
        }
        
        func updateDate(_ newDate: Date) {
            self.date = newDate
            self.weatherData = nil // Xóa dữ liệu cũ khi thay đổi ngày
            fetchWeather()
        }
    
}

struct WeatherResponse: Codable {
    struct Forecast: Codable {
        let forecastday: [ForecastDay]
    }
    struct ForecastDay: Codable {
        let day: Day
    }
    struct Day: Codable {
        let maxtemp_c: Double
        let mintemp_c: Double
        let condition: Condition
    }
    struct Condition: Codable {
        let text: String
    }
    let forecast: Forecast
}
