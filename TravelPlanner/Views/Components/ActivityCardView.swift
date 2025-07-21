import SwiftUI

struct ActivityCardView: View {
    let activity: TripActivity
    
    var body: some View {
        HStack(alignment: .top) {
            ZStack {
                Circle()
                    .fill(Color.WidgetBackground1)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color.line, lineWidth: 1)
                    )
                VStack{
                    Text("\(Formatter.formatTime(activity.startTime))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("→")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("\(Formatter.formatTime(activity.endTime))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                
                
                
            }
            VStack(alignment: .leading) {
                HStack {
                    Image("activity")
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("Hoạt động: ")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Text(activity.activity)
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
                    Text(activity.address.isEmpty ? "Không có địa chỉ" : activity.address)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                Divider()
                GeometryReader { geometry in
                    let sizeWidth = geometry.size.width
                    
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Text("Giá:")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .underline()
                            Text(Formatter.formatCost(activity.estimatedCost))
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Divider()
                        Spacer()
                        VStack(spacing: 10) {
                            Text("Chi tiêu thực tế")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .underline()
                            Text(Formatter.formatCost(activity.actualCost))
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        Spacer()
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
