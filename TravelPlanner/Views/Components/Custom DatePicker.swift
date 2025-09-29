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
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.Button))
            }
            .sheet(isPresented: $showPicker) {
                VStack {
                    DatePicker(
                        "",
                        selection: $date,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .environment(\.locale, Locale(identifier: "vi_VN"))
                    .labelsHidden()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .colorScheme(.dark)
                    .padding(.bottom, 40)
                    .padding(.horizontal)
                }
                .presentationDetents([.height(300)])
                .presentationBackground(.clear)
                .background(Color.dark)
                .ignoresSafeArea()
                
            }
            
            
        }
    }
}
