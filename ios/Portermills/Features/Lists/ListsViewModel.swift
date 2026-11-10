import Foundation

/// All of the family's lists and packing-list templates.
@MainActor
final class ListsViewModel: LiveViewModel {
    @Published private(set) var lists: [FamilyList] = []
    @Published private(set) var templates: [ListTemplate] = []
    @Published private(set) var loaded = false

    var shopping: [FamilyList] { lists.filter { $0.type == .shopping } }
    var packing: [FamilyList] { lists.filter { $0.type == .packing } }

    init() { super.init(feature: "lists") }

    override func load() async {
        do {
            async let lists = api.get("/lists", as: [FamilyList].self)
            async let templates = api.get("/list-templates", as: [ListTemplate].self)
            (self.lists, self.templates) = try await (lists, templates)
            loaded = true
        } catch {
            self.error = error.userMessage
        }
    }

    func create(name: String, type: ListType, templateId: String?) {
        perform {
            try await self.api.send("POST", "/lists", body: CreateListRequest(name: name, type: type, templateId: templateId))
        }
    }

    func rename(_ list: FamilyList, to name: String) {
        perform { try await self.api.send("PATCH", "/lists/\(list.id)", body: NameRequest(name: name)) }
    }

    func delete(_ list: FamilyList) {
        perform { try await self.api.send("DELETE", "/lists/\(list.id)") }
    }

    func delete(_ template: ListTemplate) {
        perform { try await self.api.send("DELETE", "/list-templates/\(template.id)") }
    }
}
