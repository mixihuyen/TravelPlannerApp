//import SwiftUI
//import Cloudinary
//
//class CloudinaryManager: ObservableObject {
//    private let cloudinary: CLDCloudinary
//    
//    init() {
//        self.cloudinary = CloudinaryConfig.configure()
//    }
//    
//    // Hàm upload ảnh lên Cloudinary (unsigned upload)
//    func uploadImage(image: UIImage, completion: @escaping (Result<(url: String, publicId: String), Error>) -> Void) {
//        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
//            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể chuyển đổi ảnh sang dữ liệu"])))
//            return
//        }
//        
//        let params = CLDUploadRequestParams()
//            .setUploadPreset(CloudinaryConfig.uploadPreset)
//            .setFolder("trips")
//        
//        cloudinary.createUploader().upload(data: imageData, uploadPreset: CloudinaryConfig.uploadPreset) { result in
//            switch result {
//            case .success(let response):
//                if let secureUrl = response?.secureUrl, let publicId = response?.publicId {
//                    completion(.success((secureUrl, publicId)))
//                } else {
//                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không nhận được URL hoặc Public ID"])))
//                }
//            case .failure(let error):
//                completion(.failure(error))
//            }
//        }
//    }
//    
//    // Hàm xóa ảnh (gọi API DELETE trên server)
//    func deleteImage(publicId: String) async throws {
//        guard let url = URL(string: "https://your-server.com/delete-trip-image/\(publicId)") else {
//            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL không hợp lệ"])
//        }
//        var request = URLRequest(url: url)
//        request.httpMethod = "DELETE"
//        // Thêm header xác thực nếu cần
//        // request.setValue("Bearer <token>", forHTTPHeaderField: "Authorization")
//        
//        let (_, response) = try await URLSession.shared.data(for: request)
//        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
//            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Xóa ảnh thất bại"])
//        }
//    }
//    
//    // Hàm lấy URL ảnh với transformations
//    func getImageUrl(publicId: String, width: Int = 300, height: Int = 300, crop: String = "fill") -> String {
//        let transformation = CLDTransformation()
//            .setWidth(width)
//            .setHeight(height)
//            .setCrop(crop)
//        
//        return cloudinary.createUrl()
//            .setResourceType(.image)
//            .setTransformation(transformation)
//            .generate(publicId) ?? ""
//    }
//}
