import SwiftUI
import DGCharts

struct StatisticalView: View {
    @StateObject private var viewModel: TripDashboardViewModel
    @State private var chartEntries: [PieChartDataEntry] = []
    @State private var colorMap: [TripActivity: UIColor] = [:]
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var size

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
                            VStack {
                                HStack {
                                    summaryBox(title: "Thu", value: dashboard.totalEstimated)
                                    summaryBox(title: "Chi", value: dashboard.totalActual)
                                }
                                summaryBox(title: "Thu chi", value: dashboard.balance)
                            }

                            if dashboard.totalActual == 0 {
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
                                    
                                    Text("Hãy thêm chi phí của các hoạt động để theo dõi!")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 13))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 20)
                                    
                                    Spacer()
                                }
                                .padding(.top, 100)
                            } else {
                                PieChartViewWrapper(activities: dashboard.activities) { mapping in
                                    self.colorMap = mapping
                                }
                                .frame(height: 300)

                                VStack(alignment: .leading, spacing: 0) {
                                    let validActivities = dashboard.activities.filter {
                                        guard let actualCost = $0.actualCost else { return false }
                                        return actualCost > 0
                                    }
                                    
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

                                                Text("\(Formatter.formatCost(activity.actualCost ?? 0.0))")
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
                        .padding(.top, 50)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity)
                    }
                } else if viewModel.isLoading {
                    VStack {
                        LottieView(animationName: "loading2")
                            .frame(width: 50, height: 50)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .frame(
                maxWidth: size == .regular ? 600 : .infinity,
                alignment: .center
            )
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
            Text(title == "Thu chi" ? Formatter.formatCost(value) : Formatter.formatCost(value))
                .foregroundColor(title == "Thu chi" ? (value > 0 ? .blue : value < 0 ? .red : .white) : .white)
                .font(.system(size: 20))
                .fontWeight(.bold)
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
