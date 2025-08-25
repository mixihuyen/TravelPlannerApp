import Foundation
import Cloudinary
import UIKit

class CloudinaryManager: ObservableObject {
    private let cloudinary: CLDCloudinary
    
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
                completion(.success((secureUrl, publicId, imageData))) // Trả về imageData
            }
        }
    
    // Hàm upload ảnh lên Cloudinary (unsigned upload)
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
    
    
    // Hàm lấy URL ảnh với transformations
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
}
