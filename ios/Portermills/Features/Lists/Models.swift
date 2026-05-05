import Foundation

enum ListType: String, Codable { case shopping, packing }

struct ShoppingList: Identifiable, Codable {
    let id: String
    let type: ListType
    let name: String
    let archived: Bool
    let familyId: String
}

struct ListItem: Identifiable, Codable {
    let id: String
    let listId: String
    let name: String
    let checked: Bool
    let position: Int
    let addedById: String
}
