import SwiftUI

struct LocationSearchView: View {
    @StateObject private var viewModel: WeatherViewModel
    @State private var searchQuery: String = ""
    @Binding var selectedLocation: String
    @Environment(\.dismiss) private var dismiss
    
    init(initialLocation: String, date: Date, selectedLocation: Binding<String>) {
        self._viewModel = StateObject(wrappedValue: WeatherViewModel(location: initialLocation, date: date))
        self._selectedLocation = selectedLocation
    }
    
    var body: some View {
        NavigationView {
            VStack {
                    Text("Tìm kiếm địa điểm")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 30)
                    
                
                CustomTextField(
                    placeholder: "Nhập địa điểm (ví dụ: Đà Lạt)",
                    text: $searchQuery,
                    showClearButton: true,
                    onClear: {
                        searchQuery = ""
                        viewModel.locationSuggestions = []
                    },
                    showIcon: true,
                                   iconName: "location.magnifyingglass"
                )
                .padding()
                .onChange(of: searchQuery) { newQuery in
                    viewModel.searchLocations(query: newQuery)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.locationSuggestions) { suggestion in
                            Button(action: {
                                // Tạo tên địa điểm đầy đủ
                                let fullLocation: String
                                if suggestion.country.lowercased() == "vietnam" && suggestion.region.isEmpty {
                                    fullLocation = "\(suggestion.name), \(suggestion.country)"
                                } else {
                                    fullLocation = "\(suggestion.name), \(suggestion.region), \(suggestion.country)"
                                }
                                selectedLocation = fullLocation
                                viewModel.updateLocation(fullLocation)
                                dismiss()
                            }) {
                                VStack(alignment: .leading) {
                                    Text(suggestion.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                    if !suggestion.region.isEmpty || suggestion.country.lowercased() != "vietnam" {
                                        Text(suggestion.region.isEmpty ? suggestion.country : "\(suggestion.region), \(suggestion.country)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.7))
                                    } else {
                                        Text(suggestion.country)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.WidgetBackground2)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            
        }
    }
}
