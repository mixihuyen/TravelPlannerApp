import SwiftUI

enum ToastType {
    case success
    case error
}

struct ToastView: View {
    var message: String
    var type: ToastType
    
    private var iconName: String {
        switch type {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .success:
            return .green
        case .error:
            return .red
        }
    }
    
    private var backgroundColor: Color {
        switch type {
        case .success:
            return Color.white
        case .error:
            return Color.white.opacity(0.95)
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
            Text(message)
                .foregroundColor(.black)
                .font(.system(size: 15, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(radius: 10)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.4), value: UUID())
    }
}
