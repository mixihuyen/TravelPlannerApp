import SwiftUI
import Photos

struct ActivityImagesWithUserView: View {
    @Environment(\.dismiss) var dismiss
    let image: ActivityImage
    @Environment(\.horizontalSizeClass) var size
    @State private var showDeleteSheet = false
        @State private var showAlert = false
        @State private var alertMessage = ""
    @StateObject private var cloudinaryManager = CloudinaryManager()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.background.ignoresSafeArea()
            ScrollView {
                HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(.leading)
                                
                        }
                        Spacer()
                        Text("Chi tiết ảnh")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    Button(action: {
                                            showDeleteSheet = true
                                        }) {
                                            Image(systemName: "ellipsis")
                                                .font(.system(size: 18, weight: .bold))
                                                .frame(width: 40, height: 40)
                                                .foregroundColor(.white)
                                                .padding(.trailing, 6)
                                        }
                    
                }
                .padding(.top, 5)

                // Content
                    VStack {
                        // Image
                        AsyncImage(url: URL(string: image.imageUrl ?? "")) { imagePhase in
                            switch imagePhase {
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 150)
                                    .background(Color.gray.opacity(0.2))
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: size == .regular ? 600 : .infinity, alignment: .center)
                                    .clipped()
                            case .failure:
                                Image(systemName: "exclamationmark.triangle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, minHeight: 150)
                                    .background(Color.gray.opacity(0.2))
                            @unknown default:
                                EmptyView()
                            }
                        }

                        // User Information
                        if let user = image.userInformation {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.pink)
                                    .frame(width: 35, height: 35)
                                    .overlay(
                                        Text(avatarInitials(for: user))
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                Text(user.username ?? "Unknown")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .frame(maxWidth: size == .regular ? 600 : .infinity, alignment: .center)
                        } else {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 35, height: 35)
                                Text("Unknown User")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .frame(maxWidth: size == .regular ? 600 : .infinity, alignment: .center)
                        }
                    }
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showDeleteSheet) {
            DeleteImageBottomSheet(
                onDelete: {
                    guard let urlString = image.imageUrl, !urlString.isEmpty else {
                        withAnimation {
                            showDeleteSheet = false
                            alertMessage = "URL ảnh không hợp lệ"
                            showAlert = true
                        }
                        return
                    }

                    // Lấy publicId từ imageUrl
                    let components = urlString.components(separatedBy: "/")
                    guard let uploadIndex = components.firstIndex(of: "upload"), components.count > uploadIndex + 2 else {
                        withAnimation {
                            showDeleteSheet = false
                            alertMessage = "Không thể trích xuất publicId từ URL"
                            showAlert = true
                        }
                        return
                    }

                    let startIndex = uploadIndex + 2
                    let endIndex = components.count - 1
                    let fileComponent = components[endIndex].components(separatedBy: ".")[0]
                    let publicId = components[startIndex..<endIndex].joined(separator: "/") + "/" + fileComponent

                    // Gọi hàm deleteImage từ CloudinaryManager
                    cloudinaryManager.deleteImage(publicId: publicId) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                withAnimation {
                                    showDeleteSheet = false
                                    alertMessage = "Xóa ảnh thành công!"
                                    showAlert = true
                                    // Gửi thông báo rằng ảnh đã bị xóa
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("ImageDeleted"),
                                        object: nil,
                                        userInfo: ["imageId": image.id]
                                    )
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        dismiss()
                                    }
                                }
                            case .failure(let error):
                                withAnimation {
                                    showDeleteSheet = false
                                    alertMessage = "Không thể xóa ảnh: \(error.localizedDescription)"
                                    showAlert = true
                                }
                            }
                        }
                    }
                },
                onCancel: {
                    withAnimation {
                        showDeleteSheet = false
                    }
                }
            )
            .presentationDetents([.height(300)])
            .presentationBackground(.clear)
            .background(Color.background)
            .ignoresSafeArea()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Thông báo"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func avatarInitials(for user: User) -> String {
        let firstInitial = user.firstName?.prefix(1) ?? ""
        let lastInitial = user.lastName?.prefix(1) ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
}
