import Foundation

struct PackingItem: Identifiable, Codable {
    let id: String
    var name: String
    var isChecked: Bool
    var assignedTo: String?

    init(id: String = UUID().uuidString, name: String, isChecked: Bool, assignedTo: String? = nil) {
        self.id = id
        self.name = name
        self.isChecked = isChecked
        self.assignedTo = assignedTo
    }
}
