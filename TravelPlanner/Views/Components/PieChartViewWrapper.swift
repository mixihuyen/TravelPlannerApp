import SwiftUI
import DGCharts

struct PieChartViewWrapper: UIViewRepresentable {
    let activities: [TripActivity]
    var onColorMappingReady: (([TripActivity: UIColor]) -> Void)? = nil

    func makeUIView(context: Context) -> PieChartView {
        let chart = PieChartView()
        chart.usePercentValuesEnabled = true
        chart.drawHoleEnabled = true
        chart.holeRadiusPercent = 0.5
        chart.transparentCircleRadiusPercent = 0.55
        chart.chartDescription.enabled = false
        chart.legend.enabled = false
        chart.rotationEnabled = true
        chart.entryLabelColor = .black
        chart.entryLabelFont = .systemFont(ofSize: 11)
        chart.holeColor = UIColor(Color.background1)
        chart.transparentCircleColor = .clear

        let marker = PieMarkerView(frame: CGRect(x: 0, y: 0, width: 140, height: 90))
        marker.chartView = chart
        chart.marker = marker

        return chart
    }

    func updateUIView(_ uiView: PieChartView, context: Context) {
        let entries = makePieEntries(from: activities)
        let dataSet = PieChartDataSet(entries: entries, label: "")
        let colors = ChartColorTemplates.material() + ChartColorTemplates.joyful()
        dataSet.colors = colors
        dataSet.sliceSpace = 2
        dataSet.selectionShift = 10

        let data = PieChartData(dataSet: dataSet)
        data.setDrawValues(false)

        uiView.data = data
        uiView.notifyDataSetChanged()

        DispatchQueue.main.async {
            // Pass color mapping to SwiftUI after chart is updated
            var mapping: [TripActivity: UIColor] = [:]
            for (index, entry) in entries.enumerated() {
                if let name = entry.data as? String,
                   let activity = activities.first(where: { $0.name == name && ($0.actualCost ?? 0) == entry.value }) {
                    mapping[activity] = colors[index % colors.count]
                }
            }
            onColorMappingReady?(mapping)
        }
    }

    private func makePieEntries(from activities: [TripActivity]) -> [PieChartDataEntry] {
        let total = activities.compactMap { $0.actualCost }.reduce(0, +)
        return activities.compactMap { activity in
            guard let actual = activity.actualCost, actual > 0 else { return nil }
            let percent = actual / total
            let shouldShowLabel = percent >= 0.15
            let shortLabel = shouldShowLabel ? (activity.name.count > 12 ? String(activity.name.prefix(10)) + "..." : activity.name) : nil
            let entry = PieChartDataEntry(value: actual, label: shortLabel)
            entry.data = activity.name as NSString
            return entry
        }
    }
}

extension TripActivity: Hashable {
    public static func == (lhs: TripActivity, rhs: TripActivity) -> Bool {
        lhs.name == rhs.name && lhs.actualCost == rhs.actualCost
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(actualCost)
    }
}


// MARK: - Extensions
extension TripActivity {
    func toPieEntry() -> PieChartDataEntry? {
        guard let actual = actualCost else { return nil }
        return PieChartDataEntry(value: actual, label: name)
    }
}

extension TripModel {
    var totalEstimated: Double {
        activities.map { $0.estimatedCost ?? 0 }.reduce(0, +)
    }

    var totalActual: Double {
        activities.map { $0.actualCost ?? 0 }.reduce(0, +)
    }
}
