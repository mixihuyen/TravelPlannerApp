import Foundation
import Cloudinary
struct CloudinaryConfig {
    static var cloudName: String {
        let name = Bundle.main.object(forInfoDictionaryKey: "CLOUDINARY_CLOUD_NAME") as? String ?? ""
        print("DEBUG: CLOUDINARY_CLOUD_NAME = \(name)")
        return name
    }
    static var apiKey: String {
        let key = Bundle.main.object(forInfoDictionaryKey: "CLOUDINARY_API_KEY") as? String ?? ""
        print("DEBUG: CLOUDINARY_API_KEY = \(key)")
        return key
    }
    static var uploadPreset: String {
        let preset = Bundle.main.object(forInfoDictionaryKey: "CLOUDINARY_UPLOAD_PRESET") as? String ?? ""
        print("DEBUG: CLOUDINARY_UPLOAD_PRESET = \(preset)")
        return preset
    }
}
