import SwiftUI

struct TotalCostCardView: View {
    var body: some View {
        VStack {
            GeometryReader { geometry in
                let sizeWith = geometry.size.width
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("Tổng giá")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("0")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    
                    Divider()
                        .frame(height: 40)
                        .background(Color.white.opacity(0.4))
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Text("Tổng chi")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("0")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    
                }
                .padding(.vertical, 40)
                
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(Color.WidgetBackground2)
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}
#Preview {
    TotalCostCardView()
}
