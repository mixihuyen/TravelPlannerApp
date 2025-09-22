import Foundation
import Combine

class ImageViewModel: ObservableObject {
    @Published var images: [ImageData] = []
    @Published var isLoading: Bool = false
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    @Published var toastType: ToastType?
    
    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager()

    func fetchImagesOfUsers() {
        guard let url = URL(string: "\(APIConfig.baseURL)/images/myImages"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            let errorMessage = "Không tìm thấy token xác thực hoặc URL không hợp lệ"
            print("❌ \(errorMessage)")
            showToast(message: errorMessage, type: .error)
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        print("📤 Gửi yêu cầu lấy ảnh đến: \(url.absoluteString)")
        
        isLoading = true
        networkManager.performRequest(request, decodeTo: ImageListResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                self.isLoading = false
                switch completionResult {
                case .failure(let error):
                    let errorMessage = "Lỗi khi lấy danh sách ảnh: \(error.localizedDescription)"
                    print("❌ \(errorMessage)")
                    self.showToast(message: errorMessage, type: .error)
                case .finished:
                    print("✅ Lấy danh sách ảnh thành công")
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.images = response.data
                print("📸 Đã nhận \(response.data.count) ảnh")
                if response.data.isEmpty {
                    self.showToast(message: "Không có ảnh nào để hiển thị", type: .error)
                }
            }
            .store(in: &cancellables)
    }
    func fetchPublicImages() {
        guard let url = URL(string: "\(APIConfig.baseURL)/images/publicImages"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            let errorMessage = "Không tìm thấy token xác thực hoặc URL không hợp lệ"
            print("❌ \(errorMessage)")
            showToast(message: errorMessage, type: .error)
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        print("📤 Gửi yêu cầu lấy ảnh công khai đến: \(url.absoluteString)")
        
        isLoading = true
        networkManager.performRequest(request, decodeTo: ImageListResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                self.isLoading = false
                switch completionResult {
                case .failure(let error):
                    let errorMessage = "Lỗi khi lấy danh sách ảnh công khai: \(error.localizedDescription)"
                    print("❌ \(errorMessage)")
                    self.showToast(message: errorMessage, type: .error)
                case .finished:
                    print("✅ Lấy danh sách ảnh công khai thành công")
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.images = response.data
                print("📸 Đã nhận \(response.data.count) ảnh công khai")
                if response.data.isEmpty {
                    self.showToast(message: "Không có ảnh công khai nào để hiển thị", type: .error)
                }
            }
            .store(in: &cancellables)
    }
    
    func uploadImage(_ imageData: Data, completion: @escaping (Result<ImageData, Error>) -> Void) {
        guard let url = URL(string: "\(APIConfig.baseURL)/images/upload"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            let errorMessage = "Không tìm thấy token xác thực hoặc URL không hợp lệ"
            print("❌ \(errorMessage)")
            showToast(message: errorMessage, type: .error)
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            return
        }
        
        var request = NetworkManager.createRequest(url: url, method: "POST", token: token)
        
        // Xác định định dạng ảnh
        let imageFormat = detectImageFormat(from: imageData)
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Tạo body cho multipart/form-data
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.\(imageFormat.fileExtension)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(imageFormat.contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Log chi tiết yêu cầu
        print("📤 Gửi yêu cầu đến: \(url.absoluteString)")
        print("📤 Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("📤 Body size: \(body.count) bytes")
        
        isLoading = true
        networkManager.performRequest(request, decodeTo: ImageUploadResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                self.isLoading = false
                switch completionResult {
                case .failure(let error):
                    let errorMessage = (error as? URLError)?.code == .badServerResponse ?
                        "Server gặp sự cố, vui lòng thử lại sau" :
                        "Lỗi khi tải ảnh: \(error.localizedDescription)"
                    print("❌ \(errorMessage) (Code: \((error as? URLError)?.code.rawValue ?? -1))")
                    self.showToast(message: errorMessage, type: .error)
                    completion(.failure(error))
                case .finished:
                    print("✅ Tải ảnh thành công")
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.images.append(response.data) // Thêm ảnh mới vào danh sách
                print("📸 Tải ảnh thành công, URL: \(response.data.url), ID: \(response.data.id)")
                self.showToast(message: "Tải ảnh thành công!", type: .success)
                completion(.success(response.data))
            }
            .store(in: &cancellables)
    }
    
    func deleteImage(imageId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(APIConfig.baseURL)/images/delete/\(imageId)"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            let errorMessage = "Không tìm thấy token xác thực hoặc URL không hợp lệ"
            print("❌ \(errorMessage)")
            showToast(message: errorMessage, type: .error)
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "DELETE", token: token)
        print("📤 Gửi yêu cầu xóa ảnh đến: \(url.absoluteString), method: DELETE")
        isLoading = true
        networkManager.performRequest(request, decodeTo: ImageDeleteResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                self.isLoading = false
                switch completionResult {
                case .failure(let error):
                    if let urlError = error as? URLError,
                       let httpStatusCode = urlError.userInfo["HTTPStatusCode"] as? Int,
                       httpStatusCode == 404 {
                        print("⚠️ Ảnh ID: \(imageId) không tồn tại trên server, coi như xóa thành công")
                        self.showToast(message: "Ảnh không tồn tại, tiếp tục quá trình", type: .error)
                        completion(.success(())) // Coi như xóa thành công
                    } else {
                        print("❌ Lỗi khi xóa ảnh ID: \(imageId), lỗi: \(error.localizedDescription)")
                        self.showToast(message: "Lỗi khi xóa ảnh: \(error.localizedDescription)", type: .error)
                        completion(.failure(error))
                    }
                case .finished:
                    print("✅ Xóa ảnh ID: \(imageId) thành công")
                    self.showToast(message: "Xóa ảnh thành công!", type: .success)
                    completion(.success(()))
                }
            } receiveValue: { response in
                print("📥 Response xóa ảnh: success=\(response.success), message=\(response.message), data=\(response.data)")
            }
            .store(in: &cancellables)
    }
    
    func showToast(message: String, type: ToastType) {
        print("📢 Đặt toast: \(message) với type: \(type)")
        DispatchQueue.main.async {
            self.toastMessage = message
            self.toastType = type
            self.showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                print("📢 Ẩn toast")
                self.showToast = false
                self.toastMessage = nil
                self.toastType = nil
            }
        }
    }
}
