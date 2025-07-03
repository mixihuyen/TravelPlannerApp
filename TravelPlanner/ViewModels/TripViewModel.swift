import Foundation

class TripViewModel: ObservableObject {
    @Published var trips: [TripModel]

    static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter
    }()

    static let sampleActivities: [TripActivity] = [
        TripActivity(
            date: TripViewModel.dateOnlyFormatter.date(from: "30/06/2025") ?? Date(),
            startTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 06:00") ?? Date(),
            endTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 08:00") ?? Date(),
            name: "Đi oto từ HN vào Huế"
        ),
        TripActivity(
            date: TripViewModel.dateOnlyFormatter.date(from: "30/06/2025") ?? Date(),
            startTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 09:00") ?? Date(),
            endTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 10:00") ?? Date(),
            name: "Gội đầu dưỡng sinh"
        ),
        TripActivity(
            date: TripViewModel.dateOnlyFormatter.date(from: "30/06/2025") ?? Date(),
            startTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 06:00") ?? Date(),
            endTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 08:00") ?? Date(),
            name: "Đi oto từ HN vào Huế"
        ),
        TripActivity(
            date: TripViewModel.dateOnlyFormatter.date(from: "30/06/2025") ?? Date(),
            startTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 09:00") ?? Date(),
            endTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 10:00") ?? Date(),
            name: "Gội đầu dưỡng sinh"
        ),
        TripActivity(
            date: TripViewModel.dateOnlyFormatter.date(from: "30/06/2025") ?? Date(),
            startTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 06:00") ?? Date(),
            endTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 08:00") ?? Date(),
            name: "Đi oto từ HN vào Huế"
        ),
        TripActivity(
            date: TripViewModel.dateOnlyFormatter.date(from: "30/06/2025") ?? Date(),
            startTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 09:00") ?? Date(),
            endTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 10:00") ?? Date(),
            name: "Gội đầu dưỡng sinh"
        ),
    ]

    static let dummyTrips: [TripModel] = [
        TripModel(name: "Đà Lạt We Coming 🤟", startDate: "30/06/2025", endDate: "07/07/2025", image: nil, activities: sampleActivities),
        TripModel(name: "Cu Đê Camping", startDate: "30/06/2025", endDate: "03/07/2025", image: nil, activities: sampleActivities),
        TripModel(name: "Hà Giang Trip", startDate: "30/06/2025", endDate: "03/07/2025", image: nil, activities: sampleActivities),
        TripModel(name: "Đà Lạt We Coming 🤟", startDate: "30/06/2025", endDate: "03/07/2025", image: nil, activities: sampleActivities),
        TripModel(name: "Cu Đê Camping", startDate: "30/06/2025", endDate: "03/07/2025", image: nil, activities: sampleActivities),
        TripModel(name: "Hà Giang Trip", startDate: "30/06/2025", endDate: "03/07/2025", image: nil, activities: sampleActivities),
        TripModel(name: "Đà Lạt We Coming 🤟", startDate: "30/06/2025", endDate: "03/07/2025", image: nil, activities: sampleActivities),
        TripModel(name: "Cu Đê Camping", startDate: "30/06/2025", endDate: "03/07/2025", image: nil, activities: sampleActivities),
        TripModel(name: "Hà Giang Trip", startDate: "30/06/2025", endDate: "03/07/2025", image: nil, activities: sampleActivities),
    ]

    init() {
        self.trips = Self.dummyTrips
    }
}
