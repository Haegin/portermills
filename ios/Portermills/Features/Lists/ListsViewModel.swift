import Foundation

@MainActor
final class ListsViewModel: ObservableObject {
    @Published var lists: [ShoppingList] = []
    @Published var itemsByList: [String: [ListItem]] = [:]
    @Published var isLoading = false

    func load() async {
        isLoading = true
        lists = (try? await APIClient.shared.get("/lists")) ?? []
        isLoading = false
    }

    func loadItems(for list: ShoppingList) async {
        let items: [ListItem] = (try? await APIClient.shared.get("/lists/\(list.id)/items")) ?? []
        itemsByList[list.id] = items
    }

    func addItem(to list: ShoppingList, name: String) async {
        guard let item: ListItem = try? await APIClient.shared.post(
            "/lists/\(list.id)/items", body: ["name": name]) else { return }
        itemsByList[list.id, default: []].append(item)
    }

    func toggleItem(_ item: ListItem, in list: ShoppingList) async {
        guard let updated: ListItem = try? await APIClient.shared.patch(
            "/lists/\(list.id)/items/\(item.id)", body: ["checked": !item.checked]) else { return }
        if let idx = itemsByList[list.id]?.firstIndex(where: { $0.id == item.id }) {
            itemsByList[list.id]![idx] = updated
        }
    }
}
