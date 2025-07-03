import SwiftUI
struct StatisticalView: View {
    var trip: TripModel

    var body: some View {
        Text("Chi tiêu cho \(trip.name)")
    }
}
