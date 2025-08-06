import SwiftUI

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
    var disableAutocorrection: Bool = true
    var showClearButton: Bool = true
    var onClear: (() -> Void)? = nil
    var showIcon: Bool = false
    var showIconImage: Bool = false
    var iconName: String = ""
    var imageName: String = ""
    var height: CGFloat = 44
    var isMultiline: Bool = false
    
    
    var body: some View {
        HStack {
            // Optional Icon or Image
            if showIcon || showIconImage {
                HStack(spacing: 8) {
                    if showIcon {
                        Image(systemName: iconName)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    if showIconImage {
                        Image("\(imageName)")
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.leading, 12)
            }
            
            // Placeholder or TextField
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, showIcon || showIconImage ? 0 : 12)
                        .padding(.top, 12)
                }
                
                if isMultiline {
                                    TextEditor(text: $text)
                                        .padding(.leading, showIcon || showIconImage ? 0 : 12)
                                        .padding(.top, 12)
                                        .padding(.bottom, 10)
                                        .padding(.trailing, showClearButton && !text.isEmpty ? 0 : 12)
                                        .foregroundColor(.white)
                                        .textInputAutocapitalization(autocapitalization)
                                        .disableAutocorrection(disableAutocorrection)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        .scrollContentBackground(.hidden) 
                                } else {
                                    TextField("", text: $text)
                                        .padding(.leading, showIcon || showIconImage ? 0 : 12)
                                        .padding(.top, 12)
                                        .padding(.bottom, 10)
                                        .padding(.trailing, showClearButton && !text.isEmpty ? 0 : 12)
                                        .foregroundColor(.white)
                                        .keyboardType(keyboardType)
                                        .textInputAutocapitalization(autocapitalization)
                                        .disableAutocorrection(disableAutocorrection)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                }
            }
            
            // Clear Button
            if showClearButton && !text.isEmpty {
                Button(action: {
                    text = ""
                    if let onClear = onClear {
                        onClear()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 12)
                }
            }
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.Button, lineWidth: 1)
        )
    }
}
