import Foundation

struct TripActivity: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let startTime: Date
    let endTime: Date
    let name: String
    
    // MARK: - Tiện ích hiển thị giờ dạng "HH:mm - HH:mm"
    var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    // MARK: - Lấy ngày dạng "dd/MM/yyyy"
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}
