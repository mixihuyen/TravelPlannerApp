import Foundation
import Cloudinary
import UIKit
import Combine

class CloudinaryManager: ObservableObject {
    private let cloudinary: CLDCloudinary
    private let networkManager = NetworkManager()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.cloudinary = CloudinaryConfig.configure()
    }
    
    func uploadImageCover(image: UIImage, completion: @escaping (Result<(url: String, publicId: String, imageData: Data), Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            let error = NSError(domain: "CloudinaryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể chuyển đổi ảnh sang dữ liệu"])
            completion(.failure(error))
            return
        }
        
        let params = CLDUploadRequestParams()
            .setFolder("trips")
            .setResourceType(.image)
        
        cloudinary.createUploader().upload(
            data: imageData,
            uploadPreset: CloudinaryConfig.uploadPreset,
            params: params
        ).response { response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let response = response,
                  let secureUrl = response.secureUrl,
                  let publicId = response.publicId else {
                let error = NSError(domain: "CloudinaryManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Không nhận được URL hoặc Public ID"])
                completion(.failure(error))
                return
            }
            completion(.success((secureUrl, publicId, imageData)))
        }
    }
    
    func uploadImage(image: UIImage, completion: @escaping (Result<(url: String, publicId: String), Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            let error = NSError(domain: "CloudinaryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể chuyển đổi ảnh sang dữ liệu"])
            completion(.failure(error))
            return
        }
        
        let params = CLDUploadRequestParams()
            .setFolder("trips")
            .setResourceType(.image)
        
        cloudinary.createUploader().upload(
            data: imageData,
            uploadPreset: CloudinaryConfig.uploadPreset,
            params: params
        ).response { response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let response = response,
                  let secureUrl = response.secureUrl,
                  let publicId = response.publicId else {
                let error = NSError(domain: "CloudinaryManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Không nhận được URL hoặc Public ID"])
                completion(.failure(error))
                return
            }
            completion(.success((secureUrl, publicId)))
        }
    }
    
    func getImageUrl(publicId: String, width: Int = 300, height: Int = 300, crop: String = "fill") -> String {
        let transformation = CLDTransformation()
            .setWidth(width)
            .setHeight(height)
            .setCrop(crop)
        
        return cloudinary.createUrl()
            .setResourceType(.image)
            .setTransformation(transformation)
            .generate(publicId) ?? ""
    }
    
    func deleteImage(publicId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(APIConfig.baseURL)/utils/delete-cloudinary-image/\(publicId)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            let error = NSError(domain: "CloudinaryManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "URL hoặc token không hợp lệ"])
            print("❌ URL hoặc Token không hợp lệ: \(publicId)")
            completion(.failure(error))
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
        print("📤 Gửi yêu cầu DELETE đến: \(url.absoluteString), publicId: \(publicId)")
        
        networkManager.performRequest(request, decodeTo: VoidResponse.self)
            .sink { completionResult in
                switch completionResult {
                case .failure(let error):
                    print("❌ Lỗi khi xóa ảnh: \(error.localizedDescription), publicId: \(publicId)")
                    completion(.failure(error))
                case .finished:
                    print("🗑️ Xóa ảnh thành công, publicId: \(publicId)")
                    completion(.success(()))
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
}
