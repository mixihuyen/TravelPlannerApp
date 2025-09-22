import Foundation

struct ActivityImagesResponse: Codable {
    let success: Bool
    let message: String?
    let statusCode: Int
    let reasonStatusCode: String
    let data: [ImageData]?
}
