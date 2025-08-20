import SwiftUI

struct CustomNumberTextField: View {
    @Binding var value: Double
    @State private var text: String = ""
    
    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    var body: some View {
        HStack {
            TextField("", text: $text) { isEditing in
                if isEditing && value == 0.0 {
                    text = ""
                }
            } onCommit: {
                updateValue()
            }
            .keyboardType(.decimalPad)
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .onChange(of: text) { _, newValue in
                // Lọc chỉ giữ số
                let filtered = newValue.filter { $0.isNumber }
                if filtered.isEmpty {
                    text = ""
                    value = 0.0
                } else if let number = Double(filtered) {
                    text = formatter.string(from: NSNumber(value: number)) ?? filtered
                    value = number
                } else {
                    text = filtered
                    value = 0.0
                }
            }
            .onAppear {
                text = value == 0.0 ? "" : formatter.string(from: NSNumber(value: value)) ?? ""
            }
            .onChange(of: value) { _, newValue in
                if newValue == 0.0 {
                    text = ""
                } else if let formatted = formatter.string(from: NSNumber(value: newValue)), formatted != text {
                    text = formatted
                }
            }
        }
        
    }
    
    private func updateValue() {
        let cleanedText = text.replacingOccurrences(of: ",", with: "")
        if let newValue = Double(cleanedText) {
            value = newValue
        } else {
            value = 0.0
            text = ""
        }
    }
}
