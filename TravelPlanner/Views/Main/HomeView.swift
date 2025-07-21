import SwiftUI

struct HomeView: View {
    @Environment(\.horizontalSizeClass) var size
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            VStack {
                ZStack (alignment: .center) {
                    Rectangle()
                        .fill(Color.background2)
                        .ignoresSafeArea()
                    
                    Text("Feed")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.white)
                }
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                ScrollView {
                        ForEach(ImageViewModel.sampleImages) { item in
                            VStack(spacing: 0) {
                                Image(item.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(
                                        maxWidth: size == .regular ? 600 : .infinity,
                                        alignment: .center
                                    )
                                    .clipped()
                                
                                
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 35, height: 35)
                                    
                                    Text(item.userName)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .frame(
                                    maxWidth: size == .regular ? 600 : .infinity,
                                    alignment: .center
                                )
                            }
                            .padding(.bottom, 32)
                        }
                        
                    }
                .padding(.top , -7)
                }
                
                
            
            
        }
    }
}
#Preview {
    HomeView()
}
