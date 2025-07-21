import SwiftUI

struct ActivityView: View {
    @Environment(\.dismiss) var dismiss
    let date: Date
    let activities: [TripActivity]
    
    var body: some View {
            ZStack (alignment: .topLeading){
                Color.background.ignoresSafeArea()
                VStack (alignment: .leading){
                    Button(action: {
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18))
                            Text("Hoạt động")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                ScrollView {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, 15)
                        
                        GeometryReader { geometry in
                            let size = geometry.size.width
                            HStack {
                                WeatherCardView()
                                    .frame(width: size * 0.35)
                                
                                TotalCostCardView()
                            }
                        }
                        .frame(height: 140)
                        
                        
                        
                        HStack {
                            if activities.isEmpty {
                                VStack(spacing: 8) {
                                    Image("empty")
                                        .resizable()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(.gray)

                                    Text("Chưa có hoạt động nào")
                                        .foregroundColor(.gray)
                                        .font(.subheadline)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 100)
                            } else {
                                VStack(spacing: 16) {
                                    ForEach(activities) { activity in
                                        ActivityCardView(activity: activity)
                                    }
                                }
                            }
                        }
                    }
                    
                    
                    
                }
                .padding(.horizontal)
                .padding(.top, 40)
                
            }
            
        .navigationBarBackButtonHidden(true)
    }
}
