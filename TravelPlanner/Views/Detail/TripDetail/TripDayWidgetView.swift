import SwiftUI

struct TripDayWidgetView: View {
    let title: String
    let activities: [TripActivity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(Color.WidgetBackground1)
                        .frame(width: 60, height: 60)
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                
                
                VStack(alignment: .leading, spacing: 4) {
                    if activities.isEmpty {
                        Text("Không có dữ liệu")
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(activities.indices, id: \.self) { index in
                            let activity = activities[index]
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.pink)
                                        .font(.system(size: 12))
                                    Text(activity.timeRange)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                                Text(activity.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .bold()
                            }
                            .padding(.vertical, 4)
                            
                            if index < activities.count - 1 {
                                Divider().background(Color.white.opacity(0.3))
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.WidgetBackground2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            
        }
        
    }
}


#Preview {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd/MM/yyyy HH:mm"
    
    let sampleActivities = [
        TripActivity(
            date: formatter.date(from: "30/06/2025 00:00")!,
            startTime: formatter.date(from: "30/06/2025 06:00")!,
            endTime: formatter.date(from: "30/06/2025 08:00")!,
            name: "Đi oto từ HN vào Huế"
        ),
        TripActivity(
            date: formatter.date(from: "30/06/2025 00:00")!,
            startTime: formatter.date(from: "30/06/2025 09:00")!,
            endTime: formatter.date(from: "30/06/2025 10:00")!,
            name: "Gội đầu dưỡng sinh"
        ),
        TripActivity(
            date: formatter.date(from: "30/06/2025 00:00")!,
            startTime: formatter.date(from: "30/06/2025 06:00")!,
            endTime: formatter.date(from: "30/06/2025 08:00")!,
            name: "Đi oto từ HN vào Huế"
        ),
        TripActivity(
            date: formatter.date(from: "30/06/2025 00:00")!,
            startTime: formatter.date(from: "30/06/2025 09:00")!,
            endTime: formatter.date(from: "30/06/2025 10:00")!,
            name: "Gội đầu dưỡng sinh"
        ),
        TripActivity(
            date: formatter.date(from: "30/06/2025 00:00")!,
            startTime: formatter.date(from: "30/06/2025 06:00")!,
            endTime: formatter.date(from: "30/06/2025 08:00")!,
            name: "Đi oto từ HN vào Huế"
        ),
        TripActivity(
            date: formatter.date(from: "30/06/2025 00:00")!,
            startTime: formatter.date(from: "30/06/2025 09:00")!,
            endTime: formatter.date(from: "30/06/2025 10:00")!,
            name: "Gội đầu dưỡng sinh"
        ),
        
    ]
    
    return TripDayWidgetView(title: "1\nTh 2", activities: sampleActivities)
}
