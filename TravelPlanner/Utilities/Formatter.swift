import Foundation

// MARK: - Date Formatter Utility
struct Formatter {
    // Formatter để parse từ chuỗi "yyyy-MM-dd"
    static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    // Formatter để hiển thị dạng "dd/MM/yyyy"
    static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter
    }()
    
    static func formatDate1(_ dateString: String) -> String {
        if let date = dateOnlyFormatter.date(from: dateString) {
            return displayDateFormatter.string(from: date)
        }
        return dateString
    }
    static let apiDateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(secondsFromGMT: 0) 
            return formatter
        }()
    static let apiDateTimeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.locale = Locale(identifier: "vi_VN")
            return formatter
        }()
    
    static func formatCost(_ cost: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return "\(formatter.string(from: NSNumber(value: cost)) ?? "0") đ"
    }
    
    static func formatTime(_ time: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "HH:mm"
        outputFormatter.locale = Locale(identifier: "vi_VN")
        outputFormatter.timeZone = TimeZone.current
        
        if let date = isoFormatter.date(from: time) {
            return outputFormatter.string(from: date)
        } else {
            return time
        }
    }
    
    static func formatDate2(_ date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .weekday], from: date)
        
        let day = components.day ?? 0
        let weekdayIndex = components.weekday ?? 1
        
        let weekdaySymbols = [
            "CN",
            "Th 2",
            "Th 3",
            "Th 4",
            "Th 5",
            "Th 6",
            "Th 7"
        ]
        
        let weekday = weekdaySymbols[weekdayIndex - 1]
        
        return "\(day)\n\(weekday)"
    }
}


