//import SwiftUI
//import DGCharts
//
//struct StatisticalView: View {
//    let trip: TripModel
//    @State private var chartEntries: [PieChartDataEntry] = []
//    @State private var colorMap: [TripActivity: UIColor] = [:]
//    
//    init(trip: TripModel) {
//        self.trip = trip
//        self._chartEntries = State(initialValue: trip.activities.compactMap { $0.toPieEntry() })
//    }
//    
//    var body: some View {
//        ZStack {
//            Color.background.ignoresSafeArea()
//            ScrollView {
//                VStack(spacing: 24) {
//                    VStack(spacing: 16) {
//                        HStack(spacing: 16) {
//                            summaryBox(title: "Thu", value: trip.totalEstimated)
//                            summaryBox(title: "Chi", value: trip.totalActual)
//                        }
//                        summaryBox(title: "Thu chi", value: trip.totalEstimated - trip.totalActual)
//                    }
//
//                    PieChartViewWrapper(activities: trip.activities) { mapping in
//                        self.colorMap = mapping
//                    }
//                    .frame(height: 300)
//
//                    VStack(alignment: .leading, spacing: 0) {
//                        let validActivities = trip.activities.filter { ($0.actualCost ?? 0) > 0 }
//                        
//                        ForEach(Array(validActivities.enumerated()), id: \.1.name) { index, activity in
//                            VStack(spacing: 12) {
//                                HStack(spacing: 12) {
//                                    Rectangle()
//                                        .fill(Color(colorMap[activity] ?? .gray))
//                                        .frame(width: 16, height: 16)
//                                        .cornerRadius(4)
//
//                                    Text(activity.name)
//                                        .foregroundColor(.white)
//                                        .font(.system(size: 18, weight: .medium))
//                                        .lineLimit(1)
//
//                                    Spacer()
//
//                                    Text((activity.actualCost ?? 0).formattedWithSeparator() + " đ")
//                                        .foregroundColor(.white)
//                                        .font(.system(size: 18, weight: .bold))
//                                }
//
//                                if index < validActivities.count - 1 {
//                                    Divider().background(Color.white.opacity(0.5))
//                                }
//                            }
//                            .padding(.vertical, 8)
//                            .padding(.horizontal)
//                        }
//                    }
//
//                }
//                .padding(.top, 60)
//                .padding(.horizontal)
//                .frame(maxWidth: 600) // ✅ Giới hạn chiều rộng tối đa
//                .padding(.horizontal)
//                .frame(maxWidth: .infinity) // ✅ Căn giữa
//            }
//        }
//    }
//    
//    func summaryBox(title: String, value: Double) -> some View {
//        HStack(spacing: 4) {
//            Text(title)
//                .foregroundColor(.gray)
//                .font(.caption)
//            Spacer()
//            Text(value.formattedWithSeparator() + "đ")
//                .foregroundColor(.white)
//                .fontWeight(.bold)
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.horizontal, 12)
//        .padding(.vertical, 8)
//        .overlay(
//            RoundedRectangle(cornerRadius: 10)
//                .stroke(Color.white.opacity(0.3), lineWidth: 1)
//        )
//    }
//}
//extension Double {
//    func formattedWithSeparator() -> String {
//        let formatter = NumberFormatter()
//        formatter.numberStyle = .decimal
//        formatter.groupingSeparator = "."
//        formatter.maximumFractionDigits = 0
//        return formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))"
//    }
//}
//
//
