import SwiftUI

struct ListDetailView: View {
    @StateObject private var viewModel: ListDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newItem = ""
    @State private var editingItem: ListEntry?
    @State private var renamingList = false
    @State private var savingTemplate = false
    @State private var deletingList = false
    @FocusState private var addFocused: Bool

    init(listId: String) {
        _viewModel = StateObject(wrappedValue: ListDetailViewModel(listId: listId))
    }

    var body: some View {
        List {
            ForEach(viewModel.unchecked) { item in row(item) }
            if !viewModel.checked.isEmpty {
                Section("Ticked") {
                    ForEach(viewModel.checked) { item in row(item) }
                }
            }
        }
        .overlay {
            if viewModel.list?.items.isEmpty == true {
                ContentUnavailableView("Nothing here yet", systemImage: "cart",
                                       description: Text("Add the first item below."))
            }
        }
        .safeAreaInset(edge: .bottom) { addBar }
        .navigationTitle(viewModel.list?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Button("Rename List", systemImage: "pencil") { renamingList = true }
                if viewModel.list?.type == .packing {
                    Button("Save as Template", systemImage: "square.and.arrow.down") { savingTemplate = true }
                }
                Button("Delete List", systemImage: "trash", role: .destructive) { deletingList = true }
            } label: {
                Image(systemName: "ellipsis.circle").accessibilityLabel("List options")
            }
        }
        .sheet(item: $editingItem) { item in
            TextPromptSheet(title: "Edit item", label: "Name", text: item.name) { viewModel.rename(item, to: $0) }
        }
        .sheet(isPresented: $renamingList) {
            TextPromptSheet(title: "Rename list", label: "Name", text: viewModel.list?.name ?? "") { viewModel.renameList(to: $0) }
        }
        .sheet(isPresented: $savingTemplate) {
            TextPromptSheet(title: "Save as template", label: "Template name", text: viewModel.list?.name ?? "") {
                viewModel.saveAsTemplate(named: $0)
            }
        }
        .confirmationDialog("Delete this list and everything on it, for everyone?", isPresented: $deletingList, titleVisibility: .visible) {
            Button("Delete List", role: .destructive) { viewModel.deleteList() }
        }
        .alert(viewModel.notice ?? "", isPresented: Binding(get: { viewModel.notice != nil }, set: { if !$0 { viewModel.notice = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .errorAlert($viewModel.error)
        .onChange(of: viewModel.gone) { _, gone in if gone { dismiss() } }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func row(_ item: ListEntry) -> some View {
        Button { viewModel.toggle(item) } label: {
            HStack {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.checked ? Color.accentColor : .secondary)
                Text(item.name)
                    .strikethrough(item.checked)
                    .foregroundStyle(item.checked ? .secondary : .primary)
            }
        }
        .accessibilityIdentifier("item.\(item.name)")
        .accessibilityValue(item.checked ? "ticked" : "not ticked")
        .swipeActions {
            Button("Delete", role: .destructive) { viewModel.delete(item) }
            Button("Edit") { editingItem = item }.tint(.blue)
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editingItem = item }
            Button("Delete", systemImage: "trash", role: .destructive) { viewModel.delete(item) }
        }
    }

    private var addBar: some View {
        HStack {
            TextField("Add an item", text: $newItem)
                .focused($addFocused)
                .submitLabel(.done)
                .onSubmit(add)
                .accessibilityIdentifier("list.newItem")
            Button(action: add) { Image(systemName: "plus.circle.fill").font(.title2) }
                .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Add item")
        }
        .padding(12)
        .background(.bar)
    }

    private func add() {
        let name = newItem.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        viewModel.add(name)
        newItem = ""
        addFocused = true
    }
}
