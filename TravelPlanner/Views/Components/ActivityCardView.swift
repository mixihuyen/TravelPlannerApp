
import SwiftUI

struct ActivityCardView: View {
    let activity: TripActivity
    
    var body: some View {
        HStack (alignment: .top) {
            ZStack {
                Circle()
                    .fill(Color.WidgetBackground1)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color.line, lineWidth: 1)
                    )
                Text(activity.timeRange2)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading) {
                HStack {
                    Image("activity")
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("Hoạt động: ")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Text(activity.name)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    
                }
                Divider()
                HStack {
                    Image("address")
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("Địa điểm: ")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Text(activity.address ?? "Không có địa chỉ")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                Divider()
                GeometryReader { geometry in
                    let sizeWidth = geometry.size.width
                    
                    HStack{
                        VStack (spacing: 10) {
                            Text("Giá:")
                                .font(.system(size: 14, weight: .bold, ))
                                .foregroundColor(.white)
                                .underline()
                            Text("\(activity.estimatedCost ?? 0, specifier: "%.0f") VNĐ")
                            
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        .frame(width: sizeWidth/2)
                        Divider()
                        VStack (spacing: 10) {
                            Text("Chi tiêu thực tế")
                                .font(.system(size: 14, weight: .bold,))
                                .foregroundColor(.white)
                                .underline()
                            Text("\(activity.actualCost ?? 0, specifier: "%.0f") VNĐ")
                            
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        .frame(width: sizeWidth/2)
                    }
                    .padding(.vertical, 16)
                    
                }
                .frame(height: 80)
                
                
                Divider()
                HStack {
                    Image("note")
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("Ghi chú: ")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Text(activity.note ?? "Không có ghi chú")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.WidgetBackground2)
            .clipShape(RoundedRectangle(cornerRadius: 15))
        }
    }
}

#Preview {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd/MM/yyyy HH:mm"
    
    let activity = TripActivity(
        date: formatter.date(from: "30/06/2025 00:00")!,
        startTime: formatter.date(from: "30/06/2025 06:00")!,
        endTime: formatter.date(from: "30/06/2025 08:00")!,
        name: "Đi oto từ HN vào Huế",
        address: "669 Giải Phóng",
        estimatedCost: 400_000,
        actualCost: 800_000,
        note: "Nhà xe Minh Mập\n0905347000"
    )
    
    return ZStack {
        Color.background.ignoresSafeArea()
        ActivityCardView(activity: activity)
            .padding()
    }
}
