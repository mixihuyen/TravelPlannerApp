import Foundation
import Combine
import SwiftUI
import Network

class ActivityImagesViewModel: ObservableObject {
    @Published var images: [ImageData] = []
        @Published var isLoading: Bool = false
        @Published var toastMessage: String?
        @Published var showToast: Bool = false
        @Published var toastType: ToastType?
        private var cancellables = Set<AnyCancellable>()
        private let networkManager = NetworkManager()
        private let imageViewModel = ImageViewModel()
    
    func fetchImages(tripId: Int, tripDayId: Int, activityId: Int, completion: (() -> Void)? = nil) {
        guard networkManager.isNetworkAvailable else {
            print("🌐 Mất mạng, không thể lấy danh sách ảnh")
            DispatchQueue.main.async {
                self.images = []
                self.isLoading = false
                completion?()
            }
            return
        }

        guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.tripsEndpoint)/\(tripId)/days/\(tripDayId)/activities/\(activityId)/images"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ URL hoặc token không hợp lệ")
            DispatchQueue.main.async {
                self.images = []
                self.isLoading = false
                completion?()
            }
            return
        }

        print("📤 Sending request to: \(url.absoluteString), method: GET")
        isLoading = true
        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        
        networkManager.performRequest(request, decodeTo: ActivityImagesResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                switch completionResult {
                case .failure(let error):
                    print("❌ Lỗi khi lấy danh sách ảnh: \(error)")
                    DispatchQueue.main.async {
                        self.images = []
                        self.isLoading = false 
                        completion?()
                    }
                case .finished:
                    print("✅ Lấy danh sách ảnh thành công")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        completion?()
                    }
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.images = response.data ?? []
                    print("📥 Nhận được \(self.images.count) ảnh: \(self.images.map { "id: \($0.id), url: \($0.url)" })")
                }
            }
            .store(in: &cancellables)
    }

    func uploadImages(tripId: Int, tripDayId: Int, activityId: Int, images: [UIImage], activityViewModel: ActivityViewModel, completion: (() -> Void)? = nil) {
        guard networkManager.isNetworkAvailable else {
            print("🌐 Mất mạng, không thể tải ảnh lên")
            DispatchQueue.main.async {
                activityViewModel.showToast(message: "Không thể tải ảnh lên khi không có kết nối mạng", type: .error)
                self.isLoading = false
                completion?()
            }
            return
        }

        guard !images.isEmpty else {
            print("❌ Không có ảnh nào được chọn")
            DispatchQueue.main.async {
                activityViewModel.showToast(message: "Vui lòng chọn ít nhất một ảnh", type: .error)
                self.isLoading = false
                completion?()
            }
            return
        }

        // Lấy activity hiện tại từ activityViewModel
        guard let currentActivity = activityViewModel.activities.first(where: { $0.id == activityId }) else {
            print("❌ Không tìm thấy activity với ID: \(activityId)")
            DispatchQueue.main.async {
                activityViewModel.showToast(message: "Không tìm thấy hoạt động", type: .error)
                self.isLoading = false
                completion?()
            }
            return
        }

        isLoading = true
        var uploadedImageIds: [Int] = []
        let group = DispatchGroup()

        for image in images {
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                print("❌ Không thể nén hình ảnh")
                DispatchQueue.main.async {
                    activityViewModel.showToast(message: "Một hoặc nhiều hình ảnh không hợp lệ", type: .error)
                    self.isLoading = false
                    completion?()
                }
                return
            }

            group.enter()
            imageViewModel.uploadImage(imageData) { [weak self] result in
                guard let self else {
                    group.leave()
                    return
                }
                switch result {
                case .success(let imageInfo):
                    print("✅ Tải ảnh lên thành công, URL: \(imageInfo.url), ID: \(imageInfo.id)")
                    uploadedImageIds.append(imageInfo.id)
                case .failure(let error):
                    print("❌ Lỗi khi tải ảnh lên: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        activityViewModel.showToast(message: "Lỗi khi tải ảnh lên: \(error.localizedDescription)", type: .error)
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else {
                completion?()
                return
            }

            if uploadedImageIds.isEmpty {
                print("❌ Không có ảnh nào được tải lên thành công")
                self.isLoading = false
                activityViewModel.showToast(message: "Không thể tải lên bất kỳ ảnh nào", type: .error)
                completion?()
                return
            }

            // Gọi updateActivityImages từ ActivityViewModel
            activityViewModel.updateActivityImages(tripDayId: tripDayId, activity: currentActivity, imageIds: uploadedImageIds) { result in
                switch result {
                case .success(let updatedActivity):
                    print("✅ Cập nhật activity với \(uploadedImageIds.count) ảnh thành công")
                    // Fetch lại danh sách ảnh để cập nhật UI
                    self.fetchImages(tripId: tripId, tripDayId: tripDayId, activityId: activityId) {
                        DispatchQueue.main.async {
                            activityViewModel.showToast(message: "Tải và cập nhật \(uploadedImageIds.count) ảnh thành công!", type: .success)
                            self.isLoading = false
                            completion?()
                        }
                    }
                case .failure(let error):
                    print("❌ Lỗi khi cập nhật activity: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        activityViewModel.showToast(message: "Lỗi khi cập nhật ảnh: \(error.localizedDescription)", type: .error)
                        self.isLoading = false
                        completion?()
                    }
                }
            }
        }
        
    }
    func deleteImage(tripId: Int, tripDayId: Int, activityId: Int, imageId: Int, activityViewModel: ActivityViewModel, completion: @escaping (Result<Void, Error>) -> Void) {
            guard networkManager.isNetworkAvailable else {
                print("🌐 Mất mạng, không thể xóa ảnh")
                DispatchQueue.main.async {
                    activityViewModel.showToast(message: "Không thể xóa ảnh khi không có kết nối mạng", type: .error)
                    self.isLoading = false
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không có kết nối mạng"])))
                }
                return
            }

            // Xóa ảnh khỏi danh sách cục bộ trước
            images.removeAll { $0.id == imageId }
            print("📸 Đã xóa ảnh ID: \(imageId) khỏi danh sách cục bộ")

            // Tìm activity hiện tại
            guard let currentActivity = activityViewModel.activities.first(where: { $0.id == activityId }) else {
                print("❌ Không tìm thấy activity với ID: \(activityId)")
                DispatchQueue.main.async {
                    activityViewModel.showToast(message: "Không tìm thấy hoạt động", type: .error)
                    self.isLoading = false
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy hoạt động"])))
                }
                return
            }

            // Lấy danh sách image IDs hiện tại và loại bỏ imageId cần xóa
            let existingImageIds = currentActivity.activityImages?.map { $0.id } ?? []
            let updatedImageIds = existingImageIds.filter { $0 != imageId }
            print("📸 Existing image IDs: \(existingImageIds)")
            print("📸 Updated image IDs after deletion: \(updatedImageIds)")

            // Gọi updateActivityImages để cập nhật activity trên server
            isLoading = true
            activityViewModel.updateActivityImages(tripDayId: tripDayId, activity: currentActivity, imageIds: updatedImageIds) { [weak self] result in
                guard let self else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Lỗi không xác định"])))
                    return
                }
                self.isLoading = false
                switch result {
                case .success(let updatedActivity):
                    print("✅ Cập nhật activity sau khi xóa ảnh thành công")
                    self.showToast(message: "Xóa ảnh thành công!", type: .success)
                    completion(.success(()))
                case .failure(let error):
                    print("❌ Lỗi khi cập nhật activity sau khi xóa ảnh: \(error.localizedDescription)")
                    // Phục hồi danh sách ảnh cục bộ nếu API thất bại
                    self.fetchImages(tripId: tripId, tripDayId: tripDayId, activityId: activityId)
                    self.showToast(message: "Lỗi khi xóa ảnh: \(error.localizedDescription)", type: .error)
                    completion(.failure(error))
                }
            }
        }

         func showToast(message: String, type: ToastType) {
            print("📢 Setting toast: \(message) with type: \(type)")
            DispatchQueue.main.async {
                self.toastMessage = message
                self.toastType = type
                self.showToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    print("📢 Hiding toast")
                    self.showToast = false
                    self.toastMessage = nil
                    self.toastType = nil
                }
            }
        }
}
