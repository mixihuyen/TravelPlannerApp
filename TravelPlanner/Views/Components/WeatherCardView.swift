import SwiftUI

struct WeatherCardView: View {
    let tripId: Int
    let tripDayId: Int
    let location: String
    @StateObject var viewModel: WeatherViewModel

    init(tripId: Int, tripDayId: Int, location: String) {
        self.tripId = tripId
        self.tripDayId = tripDayId
        self.location = location
        self._viewModel = StateObject(wrappedValue: WeatherViewModel(location: location, tripId: tripId, tripDayId: tripDayId))
    }

    var body: some View {
        VStack {
            let name = location.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? location
            Text(name)
                .font(.system(size: 24))
                .foregroundColor(.white)
            if viewModel.isLoading {
                Text("Đang tải thời tiết...")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            } else if let weather = viewModel.weatherData {
                Text("C: \(weather.maxTemp)° T: \(weather.minTemp)°")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            } else {
                VStack {
                    Text("Thời tiết")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    Text("không có sẵn")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(Color.WidgetBackground1)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .onAppear {
            if viewModel.location != location {
                viewModel.updateLocation(location)
            }
            print("WeatherCardView onAppear - weatherData: \(String(describing: viewModel.weatherData))")
        }
    }
}
