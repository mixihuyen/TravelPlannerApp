import SwiftUI
import DGCharts

// MARK: - Marker View (Tooltip)
class PieMarkerView: MarkerView {
    private let label = UILabel()
    private let valueLabel = UILabel()
    private let percentLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .white
        layer.cornerRadius = 10
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = CGSize(width: 0, height: 2)

        label.font = .systemFont(ofSize: 12)
        label.textColor = .black
        valueLabel.font = .boldSystemFont(ofSize: 16)
        valueLabel.textColor = .black
        percentLabel.font = .systemFont(ofSize: 11)
        percentLabel.textColor = .gray

        label.textAlignment = .center
        valueLabel.textAlignment = .center
        percentLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [label, valueLabel, percentLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .fill

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        guard let pieEntry = entry as? PieChartDataEntry else { return }

        let fullName = (pieEntry.data as? String) ?? pieEntry.label ?? "Không rõ"
        label.text = fullName

        let valueFormatted = NumberFormatter.localizedString(from: NSNumber(value: pieEntry.value), number: .decimal)
        valueLabel.text = "\(valueFormatted) đ"

        if let chartView = self.chartView as? PieChartView,
           let pieDataSet = chartView.data?.dataSets.first as? PieChartDataSet {
            
            // Ép kiểu rõ ràng entries thành PieChartDataEntry
            let entries = pieDataSet.entries.compactMap { $0 as? PieChartDataEntry }
            
            let total = entries.reduce(0.0) { $0 + $1.value }
            let percent = pieEntry.value / total * 100
            percentLabel.text = String(format: "%.2f %%", percent)
        } else {
            percentLabel.text = "0.00 %"
        }


        layoutIfNeeded()
    }


    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        let width = self.bounds.size.width
        let height = self.bounds.size.height
        var offset = CGPoint(x: -width / 2, y: -height - 10)

        if let chart = chartView {
            let chartWidth = chart.bounds.size.width
            let chartHeight = chart.bounds.size.height

            if point.x + offset.x < 0 {
                offset.x = -point.x
            } else if point.x + offset.x + width > chartWidth {
                offset.x = chartWidth - point.x - width
            }

            if point.y + offset.y < 0 {
                offset.y = 10
            }
        }

        return offset
    }
}
