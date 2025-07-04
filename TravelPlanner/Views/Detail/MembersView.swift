import SwiftUI
struct MembersView: View {
    var trip: TripModel
    let members: [TripMember]
    var columns: [GridItem] {
            if UIDevice.current.userInterfaceIdiom == .pad {
                return [GridItem(.flexible()), GridItem(.flexible())] // 2 cột cho iPad
            } else {
                return [GridItem(.flexible())] // 1 cột cho iPhone
            }
        }

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            ScrollView {
                VStack {
                    VStack {
                        HStack {
                            
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                            Image(systemName: "qrcode")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 30)
                        VStack {
                            HStack {
                                Text("Danh sách thành viên (5)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.bottom, 20)
                        }
                    }
                        .padding(.horizontal)
                    HStack {
                        VStack(spacing: 0) {
                            LazyVGrid(columns: columns, spacing: 0) {
                                            ForEach(Array(members.enumerated()), id: \.1.id) { index, member in
                                                let rowIndex = index / columns.count // tính theo hàng
                                                MemberRow(member: member)
                                                    .background(rowIndex % 2 == 0 ? Color("dark") : Color("light"))
                                            }
                                        }

                                        }
                        }
                    
                       
                                        
                    }
                    
                    
                    
                }
            .padding(.top, 40)
            }

            
        }
        
    }
