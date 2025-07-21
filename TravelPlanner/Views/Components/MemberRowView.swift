import SwiftUI

struct MemberRow: View {
    var member: Participant

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.pink)
                .frame(width: 43, height: 43)
                .overlay(
                    Text(avatarInitials())
                        .font(.headline)
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(formatRole(member.role))
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.white)

                Text(fullName())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .padding(15)
    }
    
    private func avatarInitials() -> String {
        let firstInitial = member.user.firstName?.prefix(1) ?? ""
        let lastInitial = member.user.lastName?.prefix(1) ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
    
    private func fullName() -> String {
        let firstName = member.user.firstName ?? ""
        let lastName = member.user.lastName ?? ""
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    private func formatRole(_ role: String) -> String {
        switch role.lowercased() {
        case "owner":
            return "Planner"
        case "member":
            return "Member"
        default:
            return role.capitalized
        }
    }
}
