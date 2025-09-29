import Foundation
import SDWebImage
import CoreData
import Combine
import Network

class ImageViewModel: ObservableObject {
    @Published var images: [ImageData] = []
    @Published var publicImages: [ImageData] = []
    @Published var userImages: [ImageData] = []
    @Published var isLoading: Bool = false
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    @Published var toastType: ToastType?
    
    private var cancellables = Set<AnyCancellable>()
    private var allPublicImages: [ImageData] = []
    private var allUserImages: [ImageData] = []
    private var hasMoreData: Bool = true
    private var lastLoadedImageId: Int? // Hỗ trợ phân trang
    private let ttl: TimeInterval = 300 // 5 phút
    private var cacheTimestamp: Date?
    private let coreDataStack = CoreDataStack.shared
    private let networkManager = NetworkManager.shared
    private var isInitialFetchDone: Bool = false
    
    init() {
        print("🚀 ImageViewModel initialized")
        
        // Load dữ liệu từ cache trước
        if let cachedPublicImages = loadFromCache() {
            self.allPublicImages = cachedPublicImages
            self.publicImages = cachedPublicImages
            self.cacheTimestamp = CacheManager.shared.loadCacheTimestamp(forKey: "images_cache_timestamp")
            print("📂 Sử dụng \(cachedPublicImages.count) public images từ cache")
        }
        
        if let cachedUserImages = loadUserImagesFromCache() {
            self.allUserImages = cachedUserImages
            self.userImages = cachedUserImages
            self.cacheTimestamp = CacheManager.shared.loadCacheTimestamp(forKey: "user_images_cache_timestamp")
            print("📂 Sử dụng \(cachedUserImages.count) user images từ cache")
        }
        if publicImages.isEmpty || userImages.isEmpty {
                    isLoading = true
                   
                }
        
        // Theo dõi trạng thái mạng
        networkManager.$isNetworkAvailable
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main) // Tránh nhiều thông báo mạng liên tiếp
            .sink { [weak self] isAvailable in
                guard let self else { return }
                print("🌐 Network status in ImageViewModel: \(isAvailable ? "Connected" : "Disconnected")")
                
                if isAvailable {
                                // Chỉ fetch nếu cache rỗng hoặc hết hạn
                                let cacheExpired = self.cacheTimestamp == nil || Date().timeIntervalSince(self.cacheTimestamp!) > self.ttl
                                if !self.isInitialFetchDone && cacheExpired {
                                    print("🌐 Mạng khả dụng, cache hết hạn hoặc rỗng, kiểm tra dữ liệu")
                                    if self.publicImages.isEmpty {
                                        print("🚀 Gọi fetchPublicImages vì publicImages rỗng")
                                        self.fetchPublicImages(limit: 2, force: false)
                                    }
                                    if self.userImages.isEmpty {
                                        print("🚀 Gọi fetchImagesOfUsers vì userImages rỗng")
                                        self.fetchImagesOfUsers()
                                    }
                                    self.isInitialFetchDone = true
                                } else {
                                    print("📂 Cache còn hiệu lực hoặc fetch ban đầu đã hoàn tất, bỏ qua fetch")
                                    self.isLoading = false
                                }
                            } else {
                                print("❌ Mạng không khả dụng, sử dụng dữ liệu từ cache")
                                self.showToast(message: "Không có kết nối mạng", type: .error)
                                if self.publicImages.isEmpty && self.userImages.isEmpty {
                                    self.isLoading = false
                                    self.showToast(message: "Mạng không khả dụng và không có dữ liệu cache", type: .error)
                                }
                            }
                        }
                        .store(in: &cancellables)
    }
    
    func fetchImagesOfUsers() {
        // Kiểm tra cache trước
        if let ts = cacheTimestamp, Date().timeIntervalSince(ts) < ttl, !allUserImages.isEmpty {
            print("📂 Cache còn hiệu lực, sử dụng \(allUserImages.count) user images")
            userImages = allUserImages
            isLoading = false
            return
        }
        
        guard networkManager.isNetworkAvailable else {
            print("❌ Không có kết nối mạng, sử dụng danh sách ảnh từ cache")
            showToast(message: "Không có kết nối mạng", type: .error)
            if let cachedUserImages = loadUserImagesFromCache() {
                self.allUserImages = cachedUserImages
                self.userImages = cachedUserImages
            }
            isLoading = false
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)/images/myImages"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            let errorMessage = "Không tìm thấy token xác thực hoặc URL không hợp lệ"
            print("❌ \(errorMessage)")
            showToast(message: errorMessage, type: .error)
            isLoading = false
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        print("📤 Gửi yêu cầu lấy ảnh đến: \(url.absoluteString)")
        
        isLoading = true
        networkManager.performRequest(request, decodeTo: ImageListResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                switch completionResult {
                case .failure(let error):
                    let errorMessage = error.localizedDescription.contains("Phiên đăng nhập hết hạn") ?
                        "Phiên đăng nhập hết hạn, vui lòng đăng nhập lại!" :
                        "Lỗi khi lấy danh sách ảnh: \(error.localizedDescription)"
                    print("❌ \(errorMessage)")
                    self.showToast(message: errorMessage, type: .error)
                    if let cachedUserImages = self.loadUserImagesFromCache() {
                        self.allUserImages = cachedUserImages
                        self.userImages = cachedUserImages
                    }
                    self.isLoading = false
                    if errorMessage.contains("Phiên đăng nhập hết hạn") {
                        NotificationCenter.default.post(name: NSNotification.Name("UserNeedsToLogin"), object: nil)
                    }
                case .finished:
                    print("✅ Lấy danh sách ảnh thành công")
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                print("📥 API response data count: \(response.data.count)")
                let validImages = response.data.filter { image in
                    guard let url = URL(string: image.url), url.scheme != nil else {
                        print("⚠️ Bỏ qua ảnh với URL không hợp lệ: \(image.url), imageId: \(image.id)")
                        return false
                    }
                    return true
                }
                print("📥 Valid images after filter: \(validImages.count)")
                
                Publishers.MergeMany(validImages.map { image in
                    URLSession.shared.dataTaskPublisher(for: URL(string: image.url)!)
                        .map { data, _ in
                            var updatedImage = image
                            updatedImage.imageData = data
                            return updatedImage
                        }
                        .catch { error in
                            print("❌ Lỗi tải ảnh \(image.url): \(error.localizedDescription)")
                            return Just(image)
                        }
                })
                .collect()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] updatedImages in
                    guard let self else { return }
                    print("📥 Updated user images with data: \(updatedImages.count)")
                    
                    // Debug: In danh sách ID
                    print("📜 IDs in updatedImages: \(updatedImages.map { $0.id })")
                    print("📜 IDs in allUserImages before update: \(allUserImages.map { $0.id })")
                    
                    let newImages = updatedImages
                    print("📥 New user images: \(newImages.count)")
                    
                    self.allUserImages = newImages
                    self.userImages = newImages
                    self.hasMoreData = false
                    self.cacheTimestamp = Date()
                    print("📸 Đã nhận \(response.data.count) ảnh, hợp lệ: \(updatedImages.count), hiển thị: \(self.userImages.count)")
                    
                    if self.userImages.isEmpty {
                        self.showToast(message: "Không có ảnh nào để hiển thị", type: .error)
                    }
                    
                    self.saveUserImagesToCache(images: newImages)
                    self.isLoading = false
                    print("🚀 Đặt isLoading = false, userImages.count=\(self.userImages.count)")
                }
                .store(in: &self.cancellables)
            }
            .store(in: &cancellables)
    }
    
    private func saveUserImagesToCache(images: [ImageData]) {
        let context = coreDataStack.context
        context.perform {
            images.forEach { imageData in
                let request: NSFetchRequest<UserImageEntity> = UserImageEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %d", imageData.id)
                if let existingEntity = try? context.fetch(request).first {
                    context.delete(existingEntity)
                    print("🗑️ Removed existing user image ID=\(imageData.id) before saving")
                }
                let entity = imageData.toUserImageEntity(context: context)
                context.insert(entity)
                print("💾 Saved user image to CoreData: ID=\(imageData.id), URL=\(imageData.url)")
            }
            do {
                try context.save()
                CacheManager.shared.saveCacheTimestamp(forKey: "user_images_cache_timestamp")
                self.cacheTimestamp = Date()
                print("💾 Saved \(images.count) user images to CoreData")
            } catch {
                print("❌ Error saving user images to CoreData: \(error)")
                self.showToast(message: "Lỗi khi lưu dữ liệu cache", type: .error)
            }
        }
    }
    
    private func loadUserImagesFromCache() -> [ImageData]? {
        let context = coreDataStack.context
        let request: NSFetchRequest<UserImageEntity> = UserImageEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let entities = try context.fetch(request)
            let images = entities.map { ImageData(from: $0) }
            print("📂 Loaded \(images.count) user images from cache")
            
            let limit = 2
            hasMoreData = images.count >= limit
            return images.isEmpty ? nil : images
        } catch {
            print("❌ Error loading user images from cache: \(error)")
            self.showToast(message: "Lỗi khi tải dữ liệu cache", type: .error)
            return nil
        }
    }
    
    func fetchPublicImages(limit: Int? = 2, force: Bool = false) {
        if !force, let ts = cacheTimestamp, Date().timeIntervalSince(ts) < ttl, !allPublicImages.isEmpty {
            print("📂 Cache còn hiệu lực, sử dụng \(allPublicImages.count) public images")
            publicImages = allPublicImages
            isLoading = false
            return
        }
        
        guard networkManager.isNetworkAvailable else {
            print("❌ Không có kết nối mạng, sử dụng danh sách ảnh từ cache")
            showToast(message: "Không có kết nối mạng", type: .error)
            if let cachedImages = loadFromCache() {
                self.allPublicImages = cachedImages
                self.publicImages = cachedImages
                hasMoreData = false
            } else {
                showToast(message: "Không có dữ liệu cache", type: .error)
            }
            isLoading = false
            return
        }
        
        let page = force ? 1 : ((allPublicImages.count / (limit ?? 2)) + 1)
        var urlString = "\(APIConfig.baseURL)/images/publicImages"
        var queryItems = [
            URLQueryItem(name: "sort", value: "createdAt:desc"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit ?? 2)")
        ]
        
        guard var urlComponents = URLComponents(string: urlString),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            let errorMessage = "URL hoặc token không hợp lệ"
            print("❌ \(errorMessage)")
            showToast(message: errorMessage, type: .error)
            isLoading = false
            return
        }
        
        urlComponents.queryItems = queryItems
        guard let url = urlComponents.url else {
            let errorMessage = "URL không hợp lệ"
            print("❌ \(errorMessage)")
            showToast(message: errorMessage, type: .error)
            isLoading = false
            return
        }
        
        let request = NetworkManager.createRequest(url: url, method: "GET", token: token)
        print("📤 Gửi yêu cầu lấy ảnh công khai đến: \(url.absoluteString)")
        
        isLoading = true
        networkManager.performRequest(request, decodeTo: ImageListResponse.self)
            .sink { [weak self] completionResult in
                guard let self else { return }
                switch completionResult {
                case .failure(let error):
                    let errorMessage = error.localizedDescription.contains("Phiên đăng nhập hết hạn") ?
                        "Phiên đăng nhập hết hạn, vui lòng đăng nhập lại!" :
                        "Lỗi khi lấy danh sách ảnh công khai: \(error.localizedDescription)"
                    print("❌ \(errorMessage)")
                    self.showToast(message: errorMessage, type: .error)
                    if let cachedImages = self.loadFromCache() {
                        self.allPublicImages = cachedImages
                        self.publicImages = cachedImages
                    } else {
                        self.showToast(message: "Không có dữ liệu cache", type: .error)
                    }
                    self.isLoading = false // Đặt ở đây cho trường hợp lỗi
                    self.hasMoreData = true
                    if errorMessage.contains("Phiên đăng nhập hết hạn") {
                        NotificationCenter.default.post(name: NSNotification.Name("UserNeedsToLogin"), object: nil)
                    }
                case .finished:
                    print("✅ Lấy danh sách ảnh công khai thành công")
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                print("📥 API response data count: \(response.data.count)")
                let validImages = response.data.filter { image in
                    guard let url = URL(string: image.url), url.scheme != nil else {
                        print("⚠️ Bỏ qua ảnh với URL không hợp lệ: \(image.url), imageId: \(image.id)")
                        return false
                    }
                    return true
                }
                print("📥 Valid images after filter: \(validImages.count)")
                
                Publishers.MergeMany(validImages.map { image in
                    URLSession.shared.dataTaskPublisher(for: URL(string: image.url)!)
                        .map { data, _ in
                            var updatedImage = image
                            updatedImage.imageData = data
                            return updatedImage
                        }
                        .catch { error in
                            print("❌ Lỗi tải ảnh \(image.url): \(error.localizedDescription)")
                            return Just(image)
                        }
                })
                .collect()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] updatedImages in
                    guard let self else { return }
                    print("📥 Updated images with data: \(updatedImages.count)")
                    
                    let newImages = updatedImages.filter { newImage in
                        !self.allPublicImages.contains { existingImage in
                            newImage.id == existingImage.id
                        }
                    }
                    print("📥 New images after dedup: \(newImages.count)")
                    
                    if force {
                        self.allPublicImages = newImages
                        self.publicImages = newImages
                        self.showToast(message: "Đã làm mới", type: .success)
                    } else {
                        self.allPublicImages.append(contentsOf: newImages)
                        self.publicImages = self.allPublicImages
                        print("📸 Load more: thêm \(newImages.count) ảnh")
                    }
                    
                    let currentPage = response.currentPage ?? 1
                    let totalPages = response.totalPages ?? 1
                    self.hasMoreData = currentPage < totalPages
                    self.lastLoadedImageId = newImages.last?.id
                    self.cacheTimestamp = Date()
                    print("📸 Phân trang: currentPage=\(currentPage), totalPages=\(totalPages), hasMoreData=\(self.hasMoreData)")
                    
                    self.saveToCache(images: updatedImages)
                    self.isLoading = false // Đặt isLoading = false SAU KHI cập nhật publicImages
                }
                .store(in: &self.cancellables)
            }
            .store(in: &cancellables)
    }
    
    func loadMoreImages(isPublic: Bool) {
        guard !isLoading, hasMoreData else {
            print("⚠️ Đang tải hoặc không còn ảnh, bỏ qua yêu cầu, isLoading: \(isLoading), hasMoreData: \(hasMoreData)")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.isLoading, self.hasMoreData else {
                print("⚠️ Bỏ qua load more: isLoading=\(self?.isLoading ?? true), hasMoreData=\(self?.hasMoreData ?? false)")
                return
            }
            isLoading = true
            if isPublic {
                print("🚀 Gọi fetchPublicImages để load more")
                self.fetchPublicImages(limit: 2, force: false)
            } else {
                print("⚠️ fetchImagesOfUsers không hỗ trợ phân trang, bỏ qua")
            }
            print("📸 Tổng số ảnh hiện tại: \(isPublic ? self.publicImages.count : self.userImages.count)")
        }
    }
    
    func refreshImages(isPublic: Bool) {
        print("🚀 Refresh triggered")
        isLoading = true
        
        guard networkManager.isNetworkAvailable else {
            print("❌ Không có kết nối mạng, giữ dữ liệu cache")
            showToast(message: "Không thể làm mới do mất kết nối mạng", type: .error)
            if isPublic {
                if let cachedImages = loadFromCache() {
                    self.allPublicImages = cachedImages
                    self.publicImages = cachedImages
                }
            } else {
                if let cachedImages = loadUserImagesFromCache() {
                    self.allUserImages = cachedImages
                    self.userImages = cachedImages
                }
            }
            hasMoreData = false
            return
        }
        if isPublic {
            allPublicImages.removeAll()
            publicImages.removeAll()
            clearCoreDataCache()
            fetchPublicImages(limit: 2, force: true)
        } else {
            allUserImages.removeAll()
            userImages.removeAll()
            clearUserImagesCache()
            fetchImagesOfUsers()
        }
        hasMoreData = true
        lastLoadedImageId = nil
        cacheTimestamp = nil
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
    
//    func uploadImagePublisher(_ imageData: Data) -> AnyPublisher<ImageData, Error> {
//            Future<ImageData, Error> { promise in
//                self.uploadImage(imageData) { result in
//                    switch result {
//                    case .success(let imageData):
//                        promise(.success(imageData))
//                    case .failure(let error):
//                        promise(.failure(error))
//                    }
//                }
//            }
//            .eraseToAnyPublisher()
//        }
    
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
    private func saveToCache(images: [ImageData]) {
        let context = coreDataStack.context
        context.perform {
            images.forEach { imageData in
                let request: NSFetchRequest<ImageEntity> = ImageEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %d", imageData.id)
                if let existingEntity = try? context.fetch(request).first {
                    context.delete(existingEntity)
                    print("🗑️ Removed existing image ID=\(imageData.id) before saving")
                }
                let entity = imageData.toEntity(context: context)
                context.insert(entity)
                print("💾 Saved image to CoreData: ID=\(imageData.id), URL=\(imageData.url)")
            }
            do {
                try context.save()
                CacheManager.shared.saveCacheTimestamp(forKey: "images_cache_timestamp")
                self.cacheTimestamp = Date()
                print("💾 Saved \(images.count) images to CoreData")
            } catch {
                print("❌ Error saving to CoreData: \(error)")
                self.showToast(message: "Lỗi khi lưu dữ liệu cache", type: .error)
            }
        }
    }
    
    private func loadFromCache() -> [ImageData]? {
        let context = coreDataStack.context
        let request: NSFetchRequest<ImageEntity> = ImageEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let entities = try context.fetch(request)
            let images = entities.map { ImageData(from: $0) }
            print("📂 Loaded \(images.count) public images from cache")
            
            let limit = 2
            hasMoreData = images.count >= limit
            return images.isEmpty ? nil : images
        } catch {
            print("❌ Error loading public images from cache: \(error)")
            self.showToast(message: "Lỗi khi tải dữ liệu cache", type: .error)
            return nil
        }
    }
    
    private func clearCoreDataCache() {
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ImageEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            coreDataStack.saveContext()
            print("🗑️ Cleared CoreData cache for ImageEntity")
        } catch {
            print("❌ Error clearing CoreData cache: \(error)")
            self.showToast(message: "Lỗi khi xóa cache", type: .error)
        }
    }
    
    private func clearUserImagesCache() {
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = UserImageEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            coreDataStack.saveContext()
            print("🗑️ Cleared CoreData cache for UserImageEntity")
        } catch {
            print("❌ Error clearing UserImageEntity cache: \(error)")
            self.showToast(message: "Lỗi khi xóa cache", type: .error)
        }
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
