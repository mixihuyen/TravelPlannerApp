import Foundation
enum ImageFormat {
    case png
    case jpeg
    case heic
    case unknown
    
    var contentType: String {
        switch self {
        case .png:
            return "image/png"
        case .jpeg:
            return "image/jpeg"
        case .heic:
            return "image/heic"
        case .unknown:
            return "application/octet-stream"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .png:
            return "png"
        case .jpeg:
            return "jpg"
        case .heic:
            return "heic"
        case .unknown:
            return "bin"
        }
    }
}

func detectImageFormat(from data: Data) -> ImageFormat {
    guard data.count >= 8 else { return .unknown }
    
    let header = data.prefix(8)
    let headerHex = header.map { String(format: "%02X", $0) }.joined()
    
    // PNG: 89 50 4E 47
    if headerHex.hasPrefix("89504E47") {
        return .png
    }
    // JPEG: FF D8 FF
    else if headerHex.hasPrefix("FFD8FF") {
        return .jpeg
    }
    // HEIC: ftypheic (66 74 79 70 68 65 69 63)
    else if headerHex.contains("6674797068656963") {
        return .heic
    }
    
    return .unknown
}
