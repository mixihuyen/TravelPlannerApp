import SwiftUICore
import SwiftUI
struct DeleteImageBottomSheet: View {
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.bottom, 20)

            Image(systemName: "trash.circle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.white)
            Text("Xóa ảnh")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text("Bạn có chắc chắn muốn xóa ảnh này không?")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 20) {
                Button(action: onCancel) {
                    Text("Hủy")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(10)
                }

                Button(action: onDelete) {
                    Text("Xóa")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .padding(.bottom, 40)
        .padding(.horizontal)
    }
}
