import SwiftUI

struct ActivityView: View {
    let date: Date

    var body: some View {
        VStack {
            Text("Hoạt động trong ngày:")
                .font(.title)

            Text(formatted(date)) // Hiển thị ngày
        }
        .navigationTitle("Chi tiết ngày")
    }

    func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "d 'Th' EEEE" // ví dụ: 1 Thứ ba
        return formatter.string(from: date)
    }
}
