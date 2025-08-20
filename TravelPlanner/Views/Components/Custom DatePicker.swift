import SwiftUI

struct CustomDatePicker: View {
    let title: String
    @Binding var date: Date
    @State private var showPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
            
            Button(action: {
                showPicker = true
            }) {
                HStack {
                    Text(Formatter.formatDate3.string(from: date))
                        .foregroundColor(.white)
                    
                    Spacer()
                    Image(systemName: "calendar")
                        .foregroundColor(Color.pink)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.Button))
            }
            .sheet(isPresented: $showPicker) {
                VStack {
                    DatePicker(
                        "",
                        selection: $date,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel) // có thể đổi .graphical cho đẹp
                    .environment(\.locale, Locale(identifier: "vi_VN"))
                    .labelsHidden()
                    .padding()
                    
                    Button("Xong") {
                        showPicker = false
                    }
                    .padding()
                }
                .presentationDetents([.medium]) // sheet cao vừa
            }
        }
    }
}
