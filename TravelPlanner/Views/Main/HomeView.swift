import SwiftUI

struct HomeView: View {
    @Environment(\.horizontalSizeClass) var size
    @EnvironmentObject var imageViewModel: ImageViewModel

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            VStack {
                ZStack(alignment: .center) {
                    Rectangle()
                        .fill(Color.background2)
                        .ignoresSafeArea()
                    
                    Text("Bảng tin")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                
                ScrollView {
                    ForEach(imageViewModel.images) { item in
                        VStack(spacing: 0) {
                            AsyncImage(url: URL(string: item.url)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: size == .regular ? 600 : .infinity, minHeight: 200)
                                        .background(Color.gray.opacity(0.2))
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: size == .regular ? 600 : .infinity, alignment: .center)
                                        .clipped()
                                case .failure:
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: size == .regular ? 600 : .infinity, maxHeight: 200)
                                        .foregroundColor(.red)
                                        .background(Color.gray.opacity(0.2))
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            
                            // User Information
                            if let user = item.createdByUser {
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
                        .padding(.bottom, 32)
                    }
                }
                .padding(.top, -7)
            }
        }
        .onAppear {
            imageViewModel.fetchPublicImages()
        }
    }
}
private func avatarInitials(for user: UserInformation) -> String {
    let firstInitial = user.firstName?.prefix(1) ?? ""
    let lastInitial = user.lastName?.prefix(1) ?? ""
    return "\(firstInitial)\(lastInitial)"
}
