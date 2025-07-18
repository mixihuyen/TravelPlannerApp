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
    // Dummy Members
    static let sampleMembers: [TripMember] = [
        TripMember(name: "Văn An"),
        TripMember(name: "Chí Bình"),
        TripMember(name: "Chi Chi"),
        TripMember(name: "Lê Thị Thanh Huyền", role: .planner),
        TripMember(name: "Trần Hoàng Hưng", role: .treasurer),
        TripMember(name: "Trần Hoàng Phúc", role: .member),
        TripMember(name: "Nguyễn Quốc Trung"),
        TripMember(name: "Chí Bình"),
        TripMember(name: "Chi Chi"),
        TripMember(name: "Văn An"),
        TripMember(name: "Chí Bình"),
        TripMember(name: "Chi Chi"),
        TripMember(name: "Văn An"),
        TripMember(name: "Chí Bình"),
        TripMember(name: "Chi Chi"),
        TripMember(name: "Văn An"),
        TripMember(name: "Chí Bình"),
        TripMember(name: "Chi Chi"),
        
    ]
    
    //Dummy Image
    static let sampleImage: [ImageModel] = [
        ImageModel(imageName: "image1", userName: "mixihuyen"),
        ImageModel(imageName: "image5", userName: "mixihuyen"),
        ImageModel(imageName: "image2", userName: "trungcry"),
        ImageModel(imageName: "image3", userName: "phucdev"),
        ImageModel(imageName: "image4", userName: "hungdesigner"),
        ImageModel(imageName: "image1", userName: "mixihuyen"),
        ImageModel(imageName: "image5", userName: "mixihuyen"),
        ImageModel(imageName: "image2", userName: "trungcry"),
        ImageModel(imageName: "image3", userName: "phucdev"),
        ImageModel(imageName: "image4", userName: "hungdesigner"),
        ImageModel(imageName: "image1", userName: "mixihuyen"),
        ImageModel(imageName: "image5", userName: "mixihuyen"),
        ImageModel(imageName: "image2", userName: "trungcry"),
        ImageModel(imageName: "image3", userName: "phucdev"),
        ImageModel(imageName: "image4", userName: "hungdesigner"),
        ImageModel(imageName: "image1", userName: "mixihuyen"),
        ImageModel(imageName: "image5", userName: "mixihuyen"),
        ImageModel(imageName: "image2", userName: "trungcry"),
        ImageModel(imageName: "image3", userName: "phucdev"),
        ImageModel(imageName: "image4", userName: "hungdesigner"),
        ImageModel(imageName: "image1", userName: "mixihuyen"),
        ImageModel(imageName: "image5", userName: "mixihuyen"),
        ImageModel(imageName: "image2", userName: "trungcry"),
        ImageModel(imageName: "image3", userName: "phucdev"),
        ImageModel(imageName: "image4", userName: "hungdesigner"),
        
        
    ]

    // Dummy Packing List
    static let samplePackingList = PackingList(
            sharedItems: [
                PackingItem(name: "Bếp lửa", isChecked: true, assignedTo: sampleMembers[0].id),
                PackingItem(name: "Dao", isChecked: false, assignedTo: sampleMembers[1].id),
                PackingItem(name: "Bếp lửa", isChecked: true, assignedTo: sampleMembers[0].id),
                PackingItem(name: "Dao", isChecked: false, assignedTo: sampleMembers[1].id),
                PackingItem(name: "Bếp lửa", isChecked: true, assignedTo: sampleMembers[0].id),
                PackingItem(name: "Dao", isChecked: false, assignedTo: sampleMembers[1].id),
                PackingItem(name: "Bếp lửa", isChecked: true, assignedTo: sampleMembers[0].id),
                PackingItem(name: "Dao", isChecked: false, assignedTo: sampleMembers[1].id),
                PackingItem(name: "Bếp lửa", isChecked: true, assignedTo: sampleMembers[0].id),
                PackingItem(name: "Dao", isChecked: false, assignedTo: sampleMembers[1].id),
                PackingItem(name: "Bếp lửa", isChecked: true, assignedTo: sampleMembers[0].id),
                PackingItem(name: "Dao", isChecked: false, assignedTo: sampleMembers[1].id),
                PackingItem(name: "Bếp lửa", isChecked: true, assignedTo: sampleMembers[0].id),
                PackingItem(name: "Dao", isChecked: false, assignedTo: sampleMembers[1].id),
                
            ],
            personalItems: [
                PackingItem(name: "Loa mini", isChecked: true),
                PackingItem(name: "Máy sấy", isChecked: true),
                PackingItem(name: "Sữa tắm, dầu gội", isChecked: false),
                PackingItem(name: "Lược", isChecked: true),
                PackingItem(name: "Loa mini", isChecked: true),
                PackingItem(name: "Máy sấy", isChecked: true),
                PackingItem(name: "Sữa tắm, dầu gội", isChecked: false),
                PackingItem(name: "Lược", isChecked: true),
                PackingItem(name: "Loa mini", isChecked: true),
                PackingItem(name: "Máy sấy", isChecked: true),
                PackingItem(name: "Sữa tắm, dầu gội", isChecked: false),
                PackingItem(name: "Lược", isChecked: true),
                PackingItem(name: "Loa mini", isChecked: true),
                PackingItem(name: "Máy sấy", isChecked: true),
                PackingItem(name: "Sữa tắm, dầu gội", isChecked: false),
                PackingItem(name: "Lược", isChecked: true),
                PackingItem(name: "Loa mini", isChecked: true),
                PackingItem(name: "Máy sấy", isChecked: true),
                PackingItem(name: "Sữa tắm, dầu gội", isChecked: false),
                PackingItem(name: "Lược", isChecked: true),
                PackingItem(name: "Loa mini", isChecked: true),
                PackingItem(name: "Máy sấy", isChecked: true),
                PackingItem(name: "Sữa tắm, dầu gội", isChecked: false),
                PackingItem(name: "Lược", isChecked: true),
            ]
        )

    

    static let sampleActivities: [TripActivity] = [
        TripActivity(
            date: TripViewModel.dateOnlyFormatter.date(from: "30/06/2025") ?? Date(),
            startTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 06:00") ?? Date(),
            endTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 08:00") ?? Date(),
            name: "Đi oto từ HN vào Huế",
            address: "669 Giải Phóng",
            estimatedCost: 400_000,
            actualCost: 800_000,
            note: "Nhà xe Minh Mập\n0905347000"
        ),
        
        TripActivity(
            date: TripViewModel.dateOnlyFormatter.date(from: "30/06/2025") ?? Date(),
            startTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 09:00") ?? Date(),
            endTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 10:00") ?? Date(),
            name: "Đi chợ Đông Ba",
            address: "475 Đ. Chi Lăng, tổ 9, TP Huế, Thừa Thiên Huế",
            estimatedCost: 0,
            actualCost: 0,
            note: nil
        ),
        
        TripActivity(
            date: TripViewModel.dateOnlyFormatter.date(from: "30/06/2025") ?? Date(),
            startTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 12:00") ?? Date(),
            endTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 14:00") ?? Date(),
            name: "Ăn trưa tại Cầu Trường Tiền",
            address: "Quán bánh lọc Mệ Sửu, cầu Trường Tiền",
            estimatedCost: 100_000,
            actualCost: 120_000,
            note: "Ăn bánh lọc + chè"
        ),
        
        TripActivity(
            date: TripViewModel.dateOnlyFormatter.date(from: "30/06/2025") ?? Date(),
            startTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 16:00") ?? Date(),
            endTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 18:00") ?? Date(),
            name: "Ăn bún bò + uống sữa đậu",
            address: "Quán Bún Bò 3A Lê Lợi",
            estimatedCost: 50_000,
            actualCost: 50_000,
            note: nil
        )
    ]
    static let sampleActivities2: [TripActivity] = [
        TripActivity(
            date: TripViewModel.dateOnlyFormatter.date(from: "01/07/2025") ?? Date(),
            startTime: TripViewModel.dateTimeFormatter.date(from: "01/07/2025 06:00") ?? Date(),
            endTime: TripViewModel.dateTimeFormatter.date(from: "01/07/2025 08:00") ?? Date(),
            name: "Đi oto từ HN vào Quảng Bình",
            address: "669 Giải Phóng",
            estimatedCost: 300_000,
            actualCost: 600_000,
            note: "Nhà xe Minh Mập\n0905347000"
        ),
        
        TripActivity(
            date: TripViewModel.dateOnlyFormatter.date(from: "01/07/2025") ?? Date(),
            startTime: TripViewModel.dateTimeFormatter.date(from: "01/07/2025 09:00") ?? Date(),
            endTime: TripViewModel.dateTimeFormatter.date(from: "01/07/2025 10:00") ?? Date(),
            name: "Đi chợ Đông Ba",
            address: "475 Đ. Chi Lăng, tổ 9, TP Huế, Thừa Thiên Huế",
            estimatedCost: 0,
            actualCost: 0,
            note: nil
        ),
        
        TripActivity(
            date: TripViewModel.dateOnlyFormatter.date(from: "30/06/2025") ?? Date(),
            startTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 12:00") ?? Date(),
            endTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 14:00") ?? Date(),
            name: "Ăn trưa tại Cầu Nhật Lệ",
            address: "Quán bánh lọc Mệ Sửu, cầu Trường Tiền",
            estimatedCost: 100_000,
            actualCost: 120_000,
            note: "Ăn bánh lọc + chè"
        ),
        
        TripActivity(
            date: TripViewModel.dateOnlyFormatter.date(from: "30/06/2025") ?? Date(),
            startTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 16:00") ?? Date(),
            endTime: TripViewModel.dateTimeFormatter.date(from: "30/06/2025 18:00") ?? Date(),
            name: "Ăn bún bò + uống trà sửa",
            address: "Quán Bún Bò 3A Lê Lợi",
            estimatedCost: 50_000,
            actualCost: 50_000,
            note: nil
        )
    ]


    static let dummyTrips: [TripModel] = [
        TripModel(name: "Đà Lạt We Coming 🤟", startDate: "30/06/2025", endDate: "07/07/2025", image: nil, activities: sampleActivities2, members: sampleMembers, packingList: samplePackingList),
        TripModel(name: "Cu Đê Camping", startDate: "30/06/2025", endDate: "03/07/2025", image: nil, activities: sampleActivities, members: sampleMembers, packingList: samplePackingList),
        TripModel(name: "Hà Giang Trip", startDate: "30/06/2025", endDate: "03/07/2025", image: nil, activities: sampleActivities, members: sampleMembers, packingList: samplePackingList),
        TripModel(name: "Đà Lạt We Coming 🤟", startDate: "30/06/2025", endDate: "07/07/2025", image: nil, activities: sampleActivities, members: sampleMembers, packingList: samplePackingList),
        TripModel(name: "Cu Đê Camping", startDate: "30/06/2025", endDate: "03/07/2025", image: nil, activities: sampleActivities, members: sampleMembers, packingList: samplePackingList),
        TripModel(name: "Hà Giang Trip", startDate: "30/06/2025", endDate: "03/07/2025", image: nil, activities: sampleActivities, members: sampleMembers, packingList: samplePackingList),
        TripModel(name: "Đà Lạt We Coming 🤟", startDate: "30/06/2025", endDate: "07/07/2025", image: nil, activities: sampleActivities, members: sampleMembers, packingList: samplePackingList),
        TripModel(name: "Cu Đê Camping", startDate: "30/06/2025", endDate: "03/07/2025", image: nil, activities: sampleActivities, members: sampleMembers, packingList: samplePackingList),
        TripModel(name: "Hà Giang Trip", startDate: "30/06/2025", endDate: "03/07/2025", image: nil, activities: sampleActivities, members: sampleMembers, packingList: samplePackingList),
    ]

    init() {
        self.trips = Self.dummyTrips
    }
}
