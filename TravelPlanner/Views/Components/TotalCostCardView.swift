import SwiftUI

struct TotalCostCardView: View {
    let totalActualCost: Double
    let totalEstimatedCost: Double
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                let sizeWith = geometry.size.width
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("Tổng ước tính")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(Formatter.formatCost(totalEstimatedCost))")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    
                    Divider()
                        .frame(height: 40)
                        .background(Color.white.opacity(0.4))
                    Spacer()
                    
                    
                    VStack(spacing: 8) {
                        Text("Tổng thực tế")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(Formatter.formatCost(totalActualCost))")
                            .font(.system(size: 14))
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
    TotalCostCardView(totalActualCost: 1000000, totalEstimatedCost: 1200000)
}
