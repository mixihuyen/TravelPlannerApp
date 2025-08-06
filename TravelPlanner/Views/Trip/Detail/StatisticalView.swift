import SwiftUI
import DGCharts

struct StatisticalView: View {
    @StateObject private var viewModel: TripDashboardViewModel
    @State private var chartEntries: [PieChartDataEntry] = []
    @State private var colorMap: [TripActivity: UIColor] = [:]
    @Environment(\.dismiss) var dismiss

    init(tripId: Int) {
        self._viewModel = StateObject(wrappedValue: TripDashboardViewModel(tripId: tripId))
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            
            Group {
                if let dashboard = viewModel.dashboard {
                    ScrollView {
                        VStack(spacing: 24) {
                            VStack(spacing: 16) {
                                HStack(spacing: 16) {
                                    summaryBox(title: "Thu", value: dashboard.totalEstimated)
                                    summaryBox(title: "Chi", value: dashboard.totalActual)
                                }
                                summaryBox(title: "Thu chi", value: dashboard.balance)
                            }

                            if dashboard.activities.isEmpty {
                                VStack(spacing: 10) {
                                    Spacer()
                                    Image("empty")
                                        .resizable()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(.gray)
                                        .padding(.bottom, 20)
                                    
                                    Text("Chưa có hoạt động chi tiêu")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16, weight: .semibold))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 20)
                                    
                                    Text("Hãy thêm các hoạt động để theo dõi chi phí!")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 13))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 20)
                                }
                                .padding(.top, 100)
                                .frame(maxWidth: .infinity)
                            } else {
                                PieChartViewWrapper(activities: dashboard.activities) { mapping in
                                    self.colorMap = mapping
                                }
                                .frame(height: 300)

                                VStack(alignment: .leading, spacing: 0) {
                                    let validActivities = dashboard.activities.filter { $0.actualCost > 0 }
                                    
                                    ForEach(Array(validActivities.enumerated()), id: \.1.id) { index, activity in
                                        VStack(spacing: 12) {
                                            HStack(spacing: 12) {
                                                Rectangle()
                                                    .fill(Color(colorMap[activity] ?? .gray))
                                                    .frame(width: 16, height: 16)
                                                    .cornerRadius(4)

                                                Text(activity.activity)
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .lineLimit(1)

                                                Spacer()

                                                Text("\(Formatter.formatCost(activity.actualCost))")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 14, weight: .bold))
                                            }

                                            if index < validActivities.count - 1 {
                                                Divider().background(Color.white.opacity(0.5))
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                        }
                        .padding(.top, 60)
                        .padding(.horizontal)
                        .frame(maxWidth: 600)
                        .frame(maxWidth: .infinity)
                    }
                } else if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                        .padding()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.yellow)
                        
                        Text(viewModel.toastMessage ?? "Không tải được dữ liệu chi tiêu")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        if !viewModel.isOffline {
                            Button(action: {
                                viewModel.refreshDashboard()
                            }) {
                                Text("Thử lại")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .bold))
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 20)
                                    .background(Color.pink)
                                    .clipShape(Capsule())
                            }
                        } else {
                            Text("Vui lòng kiểm tra kết nối mạng")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                        }
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Quay lại")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .bold))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(Color.gray)
                                .clipShape(Capsule())
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            viewModel.fetchDashboard()
        }
    }

    func summaryBox(title: String, value: Double) -> some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text(title)
                .foregroundColor(.gray)
                .font(.caption)
            Spacer()
            Text("\(Formatter.formatCost(value))")
                .foregroundColor(.white)
                .font(.system(size: 20))
                .fontWeight(.bold)
//            Text("đ")
//                .foregroundColor(.white)
//                .font(.system(size: 14))
//                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}


