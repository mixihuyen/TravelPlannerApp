import SwiftUI

struct CustomPullToRefresh<Content: View>: View {
    var threshold: CGFloat = 120
    var holdDuration: TimeInterval = 0.8
    var content: () -> Content
    var onRefresh: () -> Void
    
    @State private var startOffset: CGFloat = 0
    @State private var currentOffset: CGFloat = 0
    @State private var isRefreshing = false
    @State private var isHolding = false
    @State private var holdStartTime: Date?

    var body: some View {
        ScrollView {
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        if startOffset == 0 {
                            startOffset = geo.frame(in: .global).minY
                        }
                    }
                    .onChange(of: geo.frame(in: .global).minY) { newOffset in
                        currentOffset = newOffset
                        let offsetDelta = currentOffset - startOffset

                        if !isRefreshing {
                            if offsetDelta > threshold {
                                // Nếu vừa bắt đầu giữ
                                if !isHolding {
                                    isHolding = true
                                    holdStartTime = Date()
                                } else if let start = holdStartTime, Date().timeIntervalSince(start) > holdDuration {
                                    isRefreshing = true
                                    isHolding = false
                                    onRefresh()
                                    
                                    // Reset sau 1.5s
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        isRefreshing = false
                                    }
                                }
                            } else {
                                // Nếu thả tay hoặc chưa đủ xa
                                isHolding = false
                                holdStartTime = nil
                            }
                        }
                    }
            }
            .frame(height: 0)
            
            VStack(spacing: 0) {
                if isRefreshing {
                    LottieView(animationName: "loading2")
                        .frame(width: 60, height: 60)
                        .padding(.bottom, 10)
                        .transition(.opacity.combined(with: .scale))
                }
                
                content()
            }
        }
    }
}
