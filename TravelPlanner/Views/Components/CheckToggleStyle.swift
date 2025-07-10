import SwiftUI

struct CheckToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square" : "square")
                .foregroundColor(.white)
                .onTapGesture {
                    configuration.isOn.toggle()
                }

            configuration.label
                .foregroundColor(.white)
                .strikethrough(configuration.isOn, color: .white)
                .opacity(configuration.isOn ? 0.5 : 1.0)
                .animation(.easeInOut, value: configuration.isOn)
        }
    }
}
