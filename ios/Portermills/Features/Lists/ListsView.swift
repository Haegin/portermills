import SwiftUI

struct ListsView: View {
    @StateObject private var vm = ListsViewModel()

    var body: some View {
        NavigationStack {
            List(vm.lists) { list in
                NavigationLink(list.name) {
                    ListDetailView(list: list, vm: vm)
                }
            }
            .navigationTitle("Lists")
            .task { await vm.load() }
        }
    }
}

struct ListDetailView: View {
    let list: ShoppingList
    @ObservedObject var vm: ListsViewModel
    @State private var newItemName = ""

    private var items: [ListItem] { vm.itemsByList[list.id] ?? [] }

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    Button {
                        Task { await vm.toggleItem(item, in: list) }
                    } label: {
                        Label(item.name, systemImage: item.checked ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.checked ? .secondary : .primary)
                    }
                }
            }

            Section {
                HStack {
                    TextField("Add item…", text: $newItemName)
                    Button("Add") {
                        let name = newItemName
                        newItemName = ""
                        Task { await vm.addItem(to: list, name: name) }
                    }
                    .disabled(newItemName.isEmpty)
                }
            }
        }
        .navigationTitle(list.name)
        .task { await vm.loadItems(for: list) }
    }
}
