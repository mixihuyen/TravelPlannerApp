//
//  HomeView.swift
//  TravelPlanner
//
//  Created by Mixi Huyen on 1/7/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var vm = TripViewModel()
    @Environment(\.horizontalSizeClass) var size
    
    var columns: [GridItem] {
        if size == .compact {
            return [GridItem(.flexible())]
        }
        else {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
    }
    
    var body: some View {
        NavigationStack{
            GeometryReader { geo in
                ZStack{
                    // MARK: Background Color
                    Color.background
                        .ignoresSafeArea()
                    VStack{
                        ScrollView{
                            VStack{
                                HStack{
                                    //MARKL: Logo
                                    Image("logo")
                                        .resizable()
                                        .frame(width: 92, height: 117)
                                        .padding()
                                    Text("Travel\n Planner")
                                        .font(.system(size: 32, weight: .bold, design: .default))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "person.circle")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                }
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
                        .padding(.top, 10)
                        Spacer()
                        ZStack{
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .frame(width: 41, height: 41)
                                .rotationEffect(.degrees(45))
                            Image(systemName: "plus")
                                .font(.system(size: 21, weight: .bold))
                        }
                    }
                }
            }
            
        }
    }
    
}

#Preview {
    HomeView()
}

