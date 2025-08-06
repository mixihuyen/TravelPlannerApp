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
                if let activityName = entry.data as? String,
                   let activity = activities.first(where: { $0.activity == activityName && $0.actualCost == entry.value }) {
                    mapping[activity] = colors[index % colors.count]
                }
            }
            onColorMappingReady?(mapping)
        }
    }

    private func makePieEntries(from activities: [TripActivity]) -> [PieChartDataEntry] {
        let total = activities.map { $0.actualCost }.reduce(0, +)
        return activities.compactMap { activity in
            guard activity.actualCost > 0 else { return nil }
            let percent = activity.actualCost / total
            let shouldShowLabel = percent >= 0.15
            let shortLabel = shouldShowLabel ? (activity.activity.count > 12 ? String(activity.activity.prefix(10)) + "..." : activity.activity) : nil
            let entry = PieChartDataEntry(value: activity.actualCost, label: shortLabel)
            entry.data = activity.activity as NSString
            return entry
        }
    }
}
