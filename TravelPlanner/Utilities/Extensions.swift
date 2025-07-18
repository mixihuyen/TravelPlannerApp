import SwiftUI

extension Color {
    static let background = LinearGradient(
        gradient: Gradient(colors: [Color("Background 1"), Color("Background 2")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let tripBackground = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color("Card 3").opacity(0.8), location: 0.56),
            .init(color: Color("Card 2"), location: 1.0)
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
    static let retangleBackground = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color("White").opacity(0), location: 0),
            .init(color: Color("Black").opacity(1), location: 1.0)
        ]),
        startPoint: .bottom,
        endPoint: .top
    )
    static let Button = LinearGradient(
        gradient: Gradient(colors: [Color("Card 1"), Color("Pink")]),
        startPoint: .leading,
        endPoint: .trailing
    )
    static let Button2 = LinearGradient(
        gradient: Gradient(colors: [Color("Gray"), Color("Drak Gray")]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let WidgetBackground1 = LinearGradient(
        gradient: Gradient(colors: [Color("Card 1"), Color("Card 2")]),
        startPoint: .leading,
        endPoint: .trailing
    )
    static let WidgetBackground2 = LinearGradient(
        gradient: Gradient(colors: [Color("Card 1"), Color("Card 2")]),
        startPoint: .trailing,
        endPoint: .leading
    )
    static let timeWidgetBackground = LinearGradient(
        gradient: Gradient(colors: [Color("Card 1"), Color("Card 2")]),
        startPoint: .top,
        endPoint: .bottom
    )
    static let lineColor = Color("Line").opacity(0.2)
    static let pink = Color("Pink")
    static let white = Color("White")
}
