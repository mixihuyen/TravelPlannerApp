import SwiftUI
struct LoginButton: View {
    var icon: String
    var text: String

    var body: some View {
        HStack {
            if icon.hasPrefix("logo-") {
                Image(icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: icon)
                    .foregroundColor(.white)
            }
            HStack{
                Spacer()
                Text(text)
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }

            
        }
        .padding()
        .background(Color.Button2)
        .cornerRadius(12)
        .frame(maxWidth: 500)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}
