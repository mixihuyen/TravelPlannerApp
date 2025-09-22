import SwiftUI
import Photos

struct ActivityImagesWithUserView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var activitiesVM: ActivityViewModel
    let image: ImageData
    let tripId: Int
    let tripDayId: Int
    let activityId: Int
    @Environment(\.horizontalSizeClass) var size
    @State private var showDeleteSheet = false
    @StateObject private var viewModel = ActivityImagesViewModel()

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
                    // Chỉ hiển thị nút xóa nếu người dùng hiện tại là người tạo ảnh
                    if canDeleteImage() {
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
                }
                .padding(.top, 5)

                // Content
                VStack {
                    // Image
                    AsyncImage(url: URL(string: image.url)) { imagePhase in
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
                    if let user = image.createdByUser {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.pink)
                                .frame(width: 35, height: 35)
                                .overlay(
                                    Text(avatarInitials(for: user))
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            Text(user.username ?? "Không xác định")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .frame(maxWidth: size == .regular ? 600 : .infinity, alignment: .center)
                    } else {
                        Text("Không có thông tin người dùng")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .frame(maxWidth: size == .regular ? 600 : .infinity, alignment: .center)
                    }
                }
            }
            .overlay(
                Group {
                    if viewModel.showToast, let message = viewModel.toastMessage, let type = viewModel.toastType {
                        ToastView(message: message, type: type)
                    }
                },
                alignment: .bottom
            )
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showDeleteSheet) {
            DeleteImageBottomSheet(
                onDelete: {
                    viewModel.deleteImage(
                        tripId: tripId,
                        tripDayId: tripDayId,
                        activityId: activityId,
                        imageId: image.id,
                        activityViewModel: activitiesVM,
                        completion: { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success:
                                    withAnimation {
                                        showDeleteSheet = false
                                        viewModel.showToast(message: "Xóa ảnh thành công!", type: .success)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            dismiss()
                                        }
                                    }
                                case .failure(let error):
                                    withAnimation {
                                        showDeleteSheet = false
                                        viewModel.showToast(message: "Lỗi khi xóa ảnh: \(error.localizedDescription)", type: .error)
                                    }
                                }
                            }
                        }
                    )
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
    }

    private func avatarInitials(for user: UserInformation) -> String {
        let firstInitial = user.firstName?.prefix(1) ?? ""
        let lastInitial = user.lastName?.prefix(1) ?? ""
        return "\(firstInitial)\(lastInitial)"
    }

    private func canDeleteImage() -> Bool {
        let currentUserId = UserDefaults.standard.integer(forKey: "userId")
        return image.createdByUserId == currentUserId
    }
    
}
