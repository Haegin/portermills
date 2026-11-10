import SwiftUI

struct ListsView: View {
    @StateObject private var viewModel = ListsViewModel()
    @State private var creating = false
    @State private var usingTemplate: ListTemplate?
    @State private var renaming: FamilyList?
    @State private var deleting: FamilyList?

    var body: some View {
        NavigationStack {
            List {
                section("Shopping", viewModel.shopping)
                section("Packing", viewModel.packing)

                if !viewModel.templates.isEmpty {
                    Section {
                        ForEach(viewModel.templates) { template in
                            Button { usingTemplate = template } label: {
                                VStack(alignment: .leading) {
                                    Text(template.name).foregroundStyle(.primary)
                                    Text(itemCountLabel(template.items.count)).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button("Delete", role: .destructive) { viewModel.delete(template) }
                            }
                        }
                    } header: {
                        Text("Packing templates")
                    } footer: {
                        Text("Tap a template to start a packing list from it.")
                    }
                }
            }
            .overlay {
                if viewModel.loaded && viewModel.lists.isEmpty && viewModel.templates.isEmpty {
                    ContentUnavailableView("No lists yet", systemImage: "checklist",
                                           description: Text("Add a shopping list or a packing list with the + button."))
                }
            }
            .navigationTitle("Lists")
            .navigationDestination(for: FamilyList.self) { list in ListDetailView(listId: list.id) }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { creating = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New list")
                    AccountMenu()
                }
            }
            .sheet(isPresented: $creating) {
                NewListSheet(templates: viewModel.templates, onCreate: viewModel.create)
            }
            .sheet(item: $usingTemplate) { template in
                TextPromptSheet(title: "New list from “\(template.name)”", label: "List name",
                                confirmLabel: "Create", text: template.name) { name in
                    viewModel.create(name: name, type: .packing, templateId: template.id)
                }
            }
            .sheet(item: $renaming) { list in
                TextPromptSheet(title: "Rename list", label: "Name", text: list.name) { viewModel.rename(list, to: $0) }
            }
            .confirmationDialog(
                "Delete “\(deleting?.name ?? "")” and everything on it, for everyone?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete List", role: .destructive) {
                    if let deleting { viewModel.delete(deleting) }
                }
            }
            .errorAlert($viewModel.error)
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ lists: [FamilyList]) -> some View {
        if !lists.isEmpty {
            Section(title) {
                ForEach(lists) { list in
                    NavigationLink(value: list) {
                        VStack(alignment: .leading) {
                            Text(list.name)
                            Text(list.itemCount == 0 ? "Empty" : "\(list.checkedCount) of \(list.itemCount) ticked")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("list.\(list.name)")
                    .swipeActions {
                        Button("Delete", role: .destructive) { deleting = list }
                        Button("Rename") { renaming = list }.tint(.blue)
                    }
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") { renaming = list }
                        Button("Delete", systemImage: "trash", role: .destructive) { deleting = list }
                    }
                }
            }
        }
    }
}

private struct NewListSheet: View {
    let templates: [ListTemplate]
    let onCreate: (String, ListType, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var type = ListType.shopping
    @State private var templateId: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $type) {
                    ForEach(ListType.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                TextField("Name", text: $name)

                if type == .packing && !templates.isEmpty {
                    Picker("Template", selection: $templateId) {
                        Text("None (start empty)").tag(String?.none)
                        ForEach(templates) { template in
                            Text("\(template.name) · \(itemCountLabel(template.items.count))").tag(Optional(template.id))
                        }
                    }
                    .onChange(of: templateId) { _, id in
                        if name.isEmpty, let template = templates.first(where: { $0.id == id }) { name = template.name }
                    }
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name.trimmingCharacters(in: .whitespaces), type, type == .packing ? templateId : nil)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
