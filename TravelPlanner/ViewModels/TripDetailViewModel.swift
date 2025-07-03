import Foundation

class TripDetailViewModel: ObservableObject {
    let trip: TripModel
    @Published var tripDays: [Date] = []

    init(trip: TripModel) {
        self.trip = trip
        generateTripDays()
    }

    private func generateTripDays() {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        guard let start = formatter.date(from: trip.startDate),
              let end = formatter.date(from: trip.endDate) else { return }

        var current = start
        while current <= end {
            tripDays.append(current)
            current = Calendar.current.date(byAdding: .day, value: 1, to: current)!
        }
    }

    func activities(for date: Date) -> [TripActivity] {
        trip.activities.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }


    func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .weekday], from: date)
        
        let day = components.day ?? 0
        let weekdayIndex = components.weekday ?? 1 // 1 = Chủ nhật

        let weekdaySymbols = [
            "CN",      // 1
            "Th 2",    // 2
            "Th 3",    // 3
            "Th 4",    // 4
            "Th 5",    // 5
            "Th 6",    // 6
            "Th 7"     // 7
        ]
        
        let weekday = weekdaySymbols[weekdayIndex - 1]
        
        return "\(day)\n\(weekday)"
    }



}
