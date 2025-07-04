import SwiftUI

struct WeatherCardView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Đà Lạt")
                .font(.system(size: 24))
                .foregroundColor(.white)
            Text("C: 20°  T: 17°")
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(Color.WidgetBackground1)
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}
