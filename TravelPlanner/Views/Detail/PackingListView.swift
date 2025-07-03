import SwiftUI
struct PackingListView: View {
    var trip: TripModel

    var body: some View {
        Text("Đồ mang theo cho \(trip.name)")
    }
}
