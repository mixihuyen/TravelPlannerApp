import SwiftUI
struct MembersView: View {
    var trip: TripModel

    var body: some View {
        Text("Danh sách thành viên cho \(trip.name)")
    }
}
