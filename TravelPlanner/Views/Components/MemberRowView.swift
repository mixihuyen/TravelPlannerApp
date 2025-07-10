import SwiftUI

struct MemberRow: View {
    var member: TripMember

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.pink)
                .frame(width: 43, height: 43)
                .overlay(
                    Text(member.name.prefix(2))
                        .font(.headline)
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                if let role = member.role {
                    Text(role.rawValue)
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(.white)
                }

                Text(member.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .padding(15)
        
    }
}
