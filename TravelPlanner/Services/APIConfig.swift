import Foundation
struct APIConfig {
    static var baseURL: String {
        let domain = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? ""
        return "https://" + domain
    }
    static let tripsEndpoint = "/trips"
    static let timeoutInterval: TimeInterval = 20
    
    static var weatherAPI: String {
        return Bundle.main.object(forInfoDictionaryKey: "WEATHER_API") as? String ?? ""
    }
}
