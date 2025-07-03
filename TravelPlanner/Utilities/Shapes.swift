import SwiftUI

struct TripCard: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Tỷ lệ dựa theo SVG viewBox: 325 x 106
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: 0, y: 15 / 106 * h))
        path.addQuadCurve(to: CGPoint(x: 15 / 325 * w, y: 0), control: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 310 / 325 * w, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: 15 / 106 * h), control: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: 57.1108 / 106 * h))
        path.addQuadCurve(to: CGPoint(x: 311.697 / 325 * w, y: 72.0145 / 106 * h),
                          control: CGPoint(x: w, y: 64.7386 / 106 * h))
        path.addLine(to: CGPoint(x: 16.6967 / 325 * w, y: 105.599 / 106 * h))
        path.addQuadCurve(to: CGPoint(x: 0, y: 90.6954 / 106 * h),
                          control: CGPoint(x: 0, y: 99.6518 / 106 * h))
        path.addLine(to: CGPoint(x: 0, y: 15 / 106 * h))

        return path
    }
}
