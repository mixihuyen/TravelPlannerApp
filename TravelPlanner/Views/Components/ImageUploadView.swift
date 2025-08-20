//import SwiftUI
//import PhotosUI
//
//struct ImageUploadView: View {
//    @StateObject private var cloudinaryManager = CloudinaryManager()
//    @State private var selectedItem: PhotosPickerItem?
//    @State private var imageUrl: String?
//    @State private var publicId: String?
//    @State private var errorMessage: String?
//    let trip: TripModel
//    @Environment(\.dismiss) var dismiss
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            // Hiển thị ảnh đã upload hoặc ảnh mặc định
//            Group {
//                if let url = imageUrl, let imageUrl = URL(string: url) {
//                    AsyncImage(url: imageUrl) { phase in
//                        switch phase {
//                        case .empty:
//                            ProgressView()
//                                .frame(height: 200)
//                        case .success(let image):
//                            image
//                                .resizable()
//                                .scaledToFit()
//                                .frame(height: 200)
//                        case .failure:
//                            Image("default_image")
//                                .resizable()
//                                .scaledToFit()
//                                .frame(height: 200)
//                        @unknown default:
//                            Image("default_image")
//                                .resizable()
//                                .scaledToFit()
//                                .frame(height: 200)
//                        }
//                    }
//                } else {
//                    Image("default_image")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(height: 200)
//                }
//            }
//            
//            // PhotosPicker để chọn ảnh
//            PhotosPicker(selection: $selectedItem, matching: .images) {
//                Text("Chọn ảnh mới")
//                    .font(.headline)
//                    .padding()
//                    .frame(maxWidth: .infinity)
//                    .background(Color.blue)
//                    .foregroundColor(.white)
//                    .cornerRadius(8)
//            }
//            .buttonStyle(.plain)
//            
//            // Hiển thị thông báo lỗi nếu có
//            if let errorMessage = errorMessage {
//                Text(errorMessage)
//                    .foregroundColor(.red)
//                    .font(.caption)
//                    .padding(.horizontal)
//            }
//        }
//        .padding()
//        .onChange(of: selectedItem) { newItem in
//            Task {
//                if let data = try? await newItem?.loadTransferable(type: Data.self),
//                   let uiImage = UIImage(data: data) {
//                    cloudinaryManager.uploadImage(image: uiImage) { result in
//                        switch result {
//                        case .success(let (url, newPublicId)):
//                            self.imageUrl = url
//                            self.publicId = newPublicId
//                            Task {
//                                // Xóa ảnh cũ nếu có
//                                if let oldPublicId = trip.publicId {
//                                    do {
//                                        try await cloudinaryManager.deleteImage(publicId: oldPublicId)
//                                    } catch {
//                                        print("Xóa ảnh cũ thất bại: \(error)")
//                                        self.errorMessage = "Không thể xóa ảnh cũ, nhưng ảnh mới đã được upload"
//                                    }
//                                }
//                                // Cập nhật TripModel
//                                do {
//                                    try await updateTripImage(tripId: trip.id, newUrl: url, newPublicId: newPublicId)
//                                    dismiss()
//                                } catch {
//                                    self.errorMessage = "Cập nhật ảnh thất bại: \(error.localizedDescription)"
//                                }
//                            }
//                        case .failure(let error):
//                            self.errorMessage = "Upload ảnh thất bại: \(error.localizedDescription)"
//                        }
//                    }
//                } else {
//                    self.errorMessage = "Không thể tải ảnh từ thư viện"
//                }
//            }
//        }
//    }
//    
//    private func updateTripImage(tripId: UUID, newUrl: String, newPublicId: String) async throws {
//        guard let url = URL(string: "https://your-server.com/update-trip-image") else {
//            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL không hợp lệ"])
//        }
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        
//        let body: [String: Any] = [
//            "tripId": tripId.uuidString,
//            "imageCoverUrl": newUrl,
//            "publicId": newPublicId
//        ]
//        request.httpBody = try JSONSerialization.data(withJSONObject: body)
//        
//        let (_, response) = try await URLSession.shared.data(for: request)
//        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
//            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cập nhật ảnh thất bại"])
//        }
//    }
//}
