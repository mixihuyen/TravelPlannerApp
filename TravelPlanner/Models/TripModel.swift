import Foundation

struct TripModel: Identifiable {
    let id =  UUID()
    let name: String
    let startDate: String
    let endDate: String
    let image: Data?
    let activities: [TripActivity]
}
