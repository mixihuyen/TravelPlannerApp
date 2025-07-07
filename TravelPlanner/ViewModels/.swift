import Foundation
import SwiftUI

class StatisticalViewModel: ObservableObject {
    let activities: [TripActivity]

    init(activities: [TripActivity]) {
        self.activities = activities
    }

    var totalEstimated: Double {
        activities.map { $0.estimatedCost ?? 0 }.reduce(0, +)
    }

    var totalActual: Double {
        activities.map { $0.actualCost ?? 0 }.reduce(0, +)
    }

    var balance: Double {
        totalEstimated - totalActual
    }

    var pieSlices: [PieSliceData] {
        var slices: [PieSliceData] = []
        let total = totalActual
        var startAngle: Double = 0
        let colors: [Color] = [.pink, .blue, .green, .orange, .purple, .yellow]

        for (index, activity) in activities.enumerated() {
            let value = activity.actualCost ?? 0
            guard value > 0 else { continue }

            let percent = value / total
            let angle = percent * 360

            let slice = PieSliceData(
                startAngle: .degrees(startAngle),
                endAngle: .degrees(startAngle + angle),
                color: colors[index % colors.count],
                label: activity.name,
                value: value,
                percent: percent * 100
            )
            slices.append(slice)
            startAngle += angle
        }

        return slices
    }

    var pieData: [PieData] {
        pieSlices.map {
            PieData(label: $0.label, value: $0.value)
        }
    }
}

func generateNiceColor(seed: Int) -> Color {
    // Sử dụng HSB để dễ kiểm soát màu đẹp hơn RGB
    let hue = Double((seed * 37) % 360) / 360.0 // Tránh trùng màu
    let saturation = 0.6 + Double((seed % 4)) * 0.1 // 0.6–1.0
    let brightness = 0.8

    return Color(hue: hue, saturation: saturation, brightness: brightness)
}


