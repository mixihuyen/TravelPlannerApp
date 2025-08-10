import Foundation
import Cloudinary

struct CloudinaryConfig {
    static let cloudName = "dfjxhxl6h"
    static let apiKey = "354721246567833"
    
    static let uploadPreset = "travel_planner"
    
    static func configure() -> CLDCloudinary {
            let config = CLDConfiguration(
                cloudName: cloudName,
                apiKey: apiKey,
                // apiSecret: apiSecret, // Bỏ comment nếu dùng authenticated upload ở server
                secure: true // Sử dụng HTTPS
            )
            return CLDCloudinary(configuration: config)
        }
}
