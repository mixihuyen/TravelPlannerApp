import Foundation
import Combine
import SwiftUI
import Cloudinary

class ActivityImagesViewModel: ObservableObject {
    @Published var images: [ActivityImage] = []
    @Published var isLoading: Bool = false
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager()
    private let cloudinaryManager = CloudinaryManager()
    
    func fetchImages(tripId: Int, tripDayId: Int, activityId: Int, completion: (() -> Void)? = nil) {
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/days/\(tripDayId)/activities/\(activityId)/images"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ Không tìm thấy token xác thực hoặc URL không hợp lệ")
            DispatchQueue.main.async {
                self.showToast(message: "Vui lòng đăng nhập lại")
                self.isLoading = false
            }
            completion?()
            return
        }
        
        print("📤 Fetch images for tripId: \(tripId), tripDayId: \(tripDayId), activityId: \(activityId), authToken: \(token)")
        
        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        isLoading = true
        networkManager.performRequest(request, decodeTo: ActivityImagesFetchResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch completionResult {
                    case .failure(let error):
                        print("❌ Fetch images failed: \(error.localizedDescription)")
                        print("🔍 URL: \(request.url?.absoluteString ?? "N/A")")
                        if let urlError = error as? URLError {
                            switch urlError.code {
                            case .badServerResponse:
                                self.showToast(message: "Lỗi server, vui lòng thử lại")
                            case .notConnectedToInternet:
                                self.showToast(message: "Không có kết nối mạng")
                            case .timedOut:
                                self.showToast(message: "Yêu cầu tải ảnh hết thời gian, vui lòng thử lại")
                            default:
                                self.showToast(message: "Lỗi khi tải ảnh: \(error.localizedDescription)")
                            }
                        } else if let decodingError = error as? DecodingError {
                            print("🔍 Decoding error: \(decodingError)")
                            self.showToast(message: "Dữ liệu từ server không hợp lệ")
                        } else {
                            self.showToast(message: "Lỗi khi tải ảnh: \(error.localizedDescription)")
                        }
                    case .finished:
                        print("✅ Fetch images completed")
                    }
                    completion?()
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                DispatchQueue.main.async {
                    print("📥 API response: \(response)")
                    // Lọc các ảnh có imageUrl từ Cloudinary
                    self.images = response.data.filter { image in
                        guard let urlString = image.imageUrl else {
                            print("⚠️ Image ID: \(image.id) has nil imageUrl")
                            return false
                        }
                        let isCloudinary = urlString.lowercased().contains("res.cloudinary.com")
                        if !isCloudinary {
                            print("⚠️ Image ID: \(image.id) filtered out (not Cloudinary): \(urlString)")
                        }
                        return isCloudinary
                    }
                    self.images.forEach { image in
                        print("📸 Image ID: \(image.id), URL: \(String(describing: image.imageUrl))")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func uploadImage(tripId: Int, tripDayId: Int, activityId: Int, image: UIImage) {
        print("📤 Bắt đầu tải ảnh lên Cloudinary")
        isLoading = true
        // Nén ảnh để giảm kích thước
        guard let compressedImageData = image.jpegData(compressionQuality: 0.7),
              let compressedImage = UIImage(data: compressedImageData) else {
            print("❌ Không thể nén hình ảnh")
            DispatchQueue.main.async {
                self.isLoading = false
                self.showToast(message: "Hình ảnh không hợp lệ")
            }
            return
        }
        
        cloudinaryManager.uploadImage(image: compressedImage) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let (imageUrl, publicId)):
                    print("✅ Tải ảnh lên Cloudinary thành công: \(imageUrl), publicId: \(publicId)")
                    // Kiểm tra URL hợp lệ trước khi gửi
                    if imageUrl.lowercased().contains("res.cloudinary.com") {
                        self.sendImageUrlToApi(tripId: tripId, tripDayId: tripDayId, activityId: activityId, imageUrl: imageUrl)
                    } else {
                        self.isLoading = false
                        print("❌ URL từ Cloudinary không hợp lệ: \(imageUrl)")
                        self.showToast(message: "URL ảnh từ Cloudinary không hợp lệ")
                    }
                case .failure(let error):
                    self.isLoading = false
                    print("❌ Lỗi khi tải ảnh lên Cloudinary: \(error.localizedDescription)")
                    self.showToast(message: "Lỗi khi tải ảnh lên: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func sendImageUrlToApi(tripId: Int, tripDayId: Int, activityId: Int, imageUrl: String) {
        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/days/\(tripDayId)/activities/\(activityId)/images"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            DispatchQueue.main.async {
                self.isLoading = false
                print("❌ Không tìm thấy token xác thực hoặc URL không hợp lệ")
                self.showToast(message: "Vui lòng đăng nhập lại")
            }
            return
        }
        
        let body: [String: String] = ["image_url": imageUrl]
        guard let requestBody = try? JSONEncoder().encode(body) else {
            DispatchQueue.main.async {
                self.isLoading = false
                print("❌ JSON Encoding Error")
                self.showToast(message: "Lỗi mã hóa dữ liệu")
            }
            return
        }
        
        print("📤 Gửi image_url: \(imageUrl) lên API")
        let request = NetworkManager.createRequest(url: url, method: "POST", token: token, body: requestBody)
        networkManager.performRequest(request, decodeTo: ActivityImageCreateResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch completionResult {
                    case .failure(let error):
                        print("❌ Lỗi khi gửi URL ảnh lên API: \(error.localizedDescription)")
                        if let urlError = error as? URLError {
                            switch urlError.code {
                            case .badServerResponse:
                                self.showToast(message: "Lỗi server, vui lòng thử lại")
                            case .notConnectedToInternet:
                                self.showToast(message: "Không có kết nối mạng")
                            default:
                                self.showToast(message: "Lỗi khi gửi ảnh: \(error.localizedDescription)")
                            }
                        } else if let decodingError = error as? DecodingError {
                            print("🔍 Decoding error: \(decodingError)")
                            self.showToast(message: "Dữ liệu từ server không hợp lệ")
                        } else {
                            self.showToast(message: "Lỗi khi gửi ảnh: \(error.localizedDescription)")
                        }
                    case .finished:
                        print("✅ Gửi URL ảnh lên API thành công")
                    }
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                DispatchQueue.main.async {
                    print("📥 API response for upload: \(response)")
                    if response.success, let urlString = response.data.imageUrl,
                       urlString.lowercased().contains("res.cloudinary.com") {
                        self.images.append(response.data)
                        print("➕ Thêm ảnh mới ID: \(response.data.id), URL: \(String(describing: response.data.imageUrl))")
                        self.showToast(message: "Tải ảnh lên thành công!")
                    } else {
                        self.showToast(message: "URL ảnh không hợp lệ từ API")
                        print("❌ Invalid or nil URL in API response: \(String(describing: response.data.imageUrl))")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func showToast(message: String) {
        print("📢 Đặt toast: \(message)")
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("📢 Ẩn toast")
            self.showToast = false
            self.toastMessage = nil
        }
    }
}
