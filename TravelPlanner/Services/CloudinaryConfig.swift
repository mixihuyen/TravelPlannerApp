import Foundation
import Cloudinary
struct CloudinaryConfig {
    static var cloudName: String {
        return Bundle.main.object(forInfoDictionaryKey: "CLOUDINARY_CLOUD_NAME") as? String ?? ""
    }
    static var apiKey: String {
        return Bundle.main.object(forInfoDictionaryKey: "CLOUDINARY_API_KEY") as? String ?? ""
    }
    static var uploadPreset: String {
        return Bundle.main.object(forInfoDictionaryKey: "CLOUDINARY_UPLOAD_PRESET") as? String ?? ""
    }

    static func configure() -> CLDCloudinary {
        let config = CLDConfiguration(
            cloudName: cloudName,
            apiKey: apiKey,
            secure: true
        )
        return CLDCloudinary(configuration: config)
    }
}
