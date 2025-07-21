import SwiftUI

struct DeleteTripBottomSheet: View {
    var onDelete: () -> Void
    var onCancel: () -> Void
    var isOffline: Bool // truyền từ View cha

    @State private var showOfflineAlert = false

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            Image(systemName: "trash.circle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.white)

            Text("Xóa chuyến đi này?")
                .font(.headline)
                .padding(.bottom, 10)
                .foregroundColor(.white)

            Text("Hành động này sẽ xóa toàn bộ dữ liệu liên quan đến chuyến đi.")
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            HStack (spacing: 16) {
                Button(action: {
                    if isOffline {
                        showOfflineAlert = true
                    } else {
                        onDelete()
                    }
                }) {
                    Text("Xóa chuyến đi")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: {
                    onCancel()
                }) {
                    Text("Hủy")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.background2)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
            }

            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .padding(.bottom, 40)
        .padding(.horizontal)
        .alert("Không thể xoá khi offline", isPresented: $showOfflineAlert) {
            Button("OK", role: .cancel) {}
        }
    }
}
