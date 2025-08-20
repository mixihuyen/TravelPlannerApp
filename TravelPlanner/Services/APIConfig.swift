import Foundation
struct APIConfig {
    static var baseURL: String {
        let url = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? ""
        print("DEBUG: BASE_URL = \(url)")
        return url
    }
    static let tripsEndpoint = "/trips"
    static let timeoutInterval: TimeInterval = 20
    
    static var fullTripsURL: URL? {
        let fullURLString = baseURL + tripsEndpoint
        print("DEBUG: Full URL = \(fullURLString)")
        return URL(string: fullURLString)
    }
}
