import SwiftUI

struct TripDayWidgetView: View {
    let title: String
    let activities: [TripActivity]
    let formatTime: (String) -> String
    
    var body: some View { 
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(Color.WidgetBackground1)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(Color.line, lineWidth: 1)
                        )

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
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(activities.indices, id: \.self) { index in
                            let activity = activities[index]
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.pink)
                                        .font(.system(size: 12))
                                    Text("\(formatTime(activity.startTime)) - \(formatTime(activity.endTime))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                                Text(activity.activity)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .bold()
                            }
                            .padding(.vertical, 4)
                            
                            if index < activities.count - 1 {
                                Divider().background(Color.white.opacity(0.3))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.WidgetBackground2)
                        
                )
                
            }
        }
    }
}
