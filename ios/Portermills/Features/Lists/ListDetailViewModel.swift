import Foundation

/// One list and its items.
@MainActor
final class ListDetailViewModel: LiveViewModel {
    let listId: String
    @Published private(set) var list: FamilyListDetail?
    /// The list was deleted, here or elsewhere; the screen should close.
    @Published private(set) var gone = false
    @Published var notice: String?

    var unchecked: [ListEntry] { list?.items.filter { !$0.checked } ?? [] }
    var checked: [ListEntry] { list?.items.filter(\.checked) ?? [] }

    init(listId: String) {
        self.listId = listId
        super.init(feature: "lists")
    }

    override func load() async {
        do {
            list = try await api.get("/lists/\(listId)", as: FamilyListDetail.self)
        } catch where error.isNotFound {
            gone = true
        } catch {
            self.error = error.userMessage
        }
    }

    func add(_ name: String) {
        perform { try await self.api.send("POST", "/lists/\(self.listId)/items", body: NameRequest(name: name)) }
    }

    func toggle(_ item: ListEntry) {
        // Show the tick straight away; the reload after the write settles it.
        if let current = list {
            list = FamilyListDetail(
                id: current.id, type: current.type, name: current.name,
                items: current.items.map {
                    $0.id == item.id
                        ? ListEntry(id: $0.id, listId: $0.listId, name: $0.name, checked: !item.checked, position: $0.position)
                        : $0
                })
        }
        perform {
            try await self.api.send("PATCH", "/lists/\(self.listId)/items/\(item.id)", body: CheckedRequest(checked: !item.checked))
        }
    }

    func rename(_ item: ListEntry, to name: String) {
        perform { try await self.api.send("PATCH", "/lists/\(self.listId)/items/\(item.id)", body: NameRequest(name: name)) }
    }

    func delete(_ item: ListEntry) {
        perform { try await self.api.send("DELETE", "/lists/\(self.listId)/items/\(item.id)") }
    }

    func renameList(to name: String) {
        perform { try await self.api.send("PATCH", "/lists/\(self.listId)", body: NameRequest(name: name)) }
    }

    func deleteList() {
        Task {
            do {
                try await api.send("DELETE", "/lists/\(listId)")
                gone = true
            } catch {
                self.error = error.userMessage
            }
        }
    }

    func saveAsTemplate(named name: String) {
        Task {
            do {
                try await api.send("POST", "/list-templates", body: SaveTemplateRequest(name: name, fromListId: listId))
                notice = "Saved “\(name)” as a template."
            } catch {
                self.error = error.userMessage
            }
        }
    }
}
