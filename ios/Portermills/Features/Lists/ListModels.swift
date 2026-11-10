import Foundation

enum ListType: String, Codable, CaseIterable {
    case shopping, packing

    var label: String { self == .shopping ? "Shopping" : "Packing" }
}

/// A shopping or packing list.
struct FamilyList: Decodable, Identifiable, Hashable {
    let id: String
    let type: ListType
    let name: String
    let itemCount: Int
    let checkedCount: Int
}

struct ListEntry: Decodable, Identifiable, Equatable {
    let id: String
    let listId: String
    let name: String
    let checked: Bool
    let position: Int?
}

struct FamilyListDetail: Decodable {
    let id: String
    let type: ListType
    let name: String
    let items: [ListEntry]
}

/// A reusable packing list.
struct ListTemplate: Decodable, Identifiable, Hashable {
    struct Item: Decodable, Hashable {
        let id: String
        let name: String
    }

    let id: String
    let name: String
    let items: [Item]
}

struct CreateListRequest: Encodable {
    let name: String
    let type: ListType
    let templateId: String?
}

struct NameRequest: Encodable {
    let name: String
}

struct CheckedRequest: Encodable {
    let checked: Bool
}

struct SaveTemplateRequest: Encodable {
    let name: String
    let fromListId: String
}

func itemCountLabel(_ count: Int) -> String { count == 1 ? "1 item" : "\(count) items" }
