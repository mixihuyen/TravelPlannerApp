import Foundation
import Combine

class ImageViewModel: ObservableObject {
    @Published var images: [ImageModel] = []
    private var cancellables = Set<AnyCancellable>()

    // Dữ liệu dummy tương tự TripViewModel.sampleImage
    static let sampleImages: [ImageModel] = [
        ImageModel(id: UUID(), imageName: "image1", userName: "mixihuyen"),
        ImageModel(id: UUID(), imageName: "image5", userName: "mixihuyen"),
        ImageModel(id: UUID(), imageName: "image2", userName: "trungcry"),
        ImageModel(id: UUID(), imageName: "image3", userName: "phucdev"),
        ImageModel(id: UUID(), imageName: "image4", userName: "hungdesigner"),
        ImageModel(id: UUID(), imageName: "image1", userName: "mixihuyen"),
        ImageModel(id: UUID(), imageName: "image5", userName: "mixihuyen"),
        ImageModel(id: UUID(), imageName: "image2", userName: "trungcry"),
        ImageModel(id: UUID(), imageName: "image3", userName: "phucdev"),
        ImageModel(id: UUID(), imageName: "image4", userName: "hungdesigner"),
        ImageModel(id: UUID(), imageName: "image1", userName: "mixihuyen"),
        ImageModel(id: UUID(), imageName: "image5", userName: "mixihuyen"),
        ImageModel(id: UUID(), imageName: "image2", userName: "trungcry"),
        ImageModel(id: UUID(), imageName: "image3", userName: "phucdev"),
        ImageModel(id: UUID(), imageName: "image4", userName: "hungdesigner")
    ]

    init() {
        // Sử dụng dữ liệu dummy ban đầu
        self.images = Self.sampleImages
    }

    // Hàm này sẽ được sử dụng nếu có API hình ảnh trong tương lai
    func fetchImages() {
        // Giả sử API là https://travel-api-79ct.onrender.com/api/v1/images
        // Hiện tại không có API, nên giữ rỗng hoặc dùng dummy
        self.images = Self.sampleImages
    }
}
