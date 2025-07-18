
import SwiftUI

struct TripView: View {
    @StateObject private var vm = TripViewModel()
    @Environment(\.horizontalSizeClass) var size
    @EnvironmentObject var navManager: NavigationManager
    
    var columns: [GridItem] {
        if size == .compact {
            return [GridItem(.flexible())]
        }
        else {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack{
                // MARK: Background Color
                Color.background
                    .ignoresSafeArea()
                VStack{
                    ZStack (alignment: .center) {
                        Rectangle()
                            .fill(Color.background2)
                            .ignoresSafeArea()
                        
                        HStack{
                            Text("Travel Planner")
                                .font(.system(size: 32, weight: .bold, design: .default))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: {
                                navManager.go(to: .createTrip)
                            }) {
                                
                                Image(systemName: "text.badge.plus")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(.white)
                                
                            }
                            
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 20)
                    }
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    
                    ScrollView{
                        VStack{
                            LazyVGrid(columns: columns, spacing: 50) {
                                ForEach(vm.trips) { trip in
                                    NavigationLink(destination: TabBar(trip: trip)) {
                                        TripCardView(trip: trip)
                                            .frame(maxWidth: .infinity)
                                        
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .frame(maxWidth: 900)
                        .frame(maxWidth: .infinity)
                    }
                    Spacer()
                    
                }
            }
            .navigationBarBackButtonHidden(true)
            
        }
        
    }
    
}

#Preview {
    TripView()
}

