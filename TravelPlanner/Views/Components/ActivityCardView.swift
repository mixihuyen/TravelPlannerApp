import SwiftUI

struct ActivityCardView: View {
    let activity: TripActivity
    let date: Date
    let tripId: Int
    let trip: TripModel
    let tripDayId: Int
    @EnvironmentObject var navManager: NavigationManager
    
    var body: some View {
        HStack(alignment: .top) {
            VStack  (spacing: 20){
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
                Image(systemName: "camera")
                    .font(.system(size: 28))
                    .foregroundColor(.pink)
                Button(action: {
                    print("📋 Navigating to ActivityImagesView with tripId: \(tripId), tripDayId: \(tripDayId), activityId: \(activity.id)")
                    navManager.go(to: .activityImages(tripId: tripId, tripDayId: tripDayId, activityId: activity.id))
                }) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 28))
                        .foregroundColor(.pink)
                }
                
            }
            Button(action: {
                let currentUserId = UserDefaults.standard.integer(forKey: "userId")
                let userRole = trip.tripParticipants?.first(where: { $0.userId == currentUserId })?.role ?? "Unknown"
                
                if userRole != "member" {
                    navManager.go(to: .editActivity(date: date, activity: activity, trip: trip, tripDayId: tripDayId))
                }
            }) {
                
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
                                Text("Chi phí uớc tính:")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .underline()
                                Text("\(Formatter.formatCost(activity.estimatedCost))")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Divider()
                            Spacer()
                            VStack(spacing: 10) {
                                Text("Chi phí thực tế")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .underline()
                                Text("\(Formatter.formatCost(activity.actualCost))")
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
    
    
    
}
