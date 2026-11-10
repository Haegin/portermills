import SwiftUI

struct WishlistDetailView: View {
    @StateObject private var viewModel: WishlistDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editing: ItemEditor.Target?

    init(wishlistId: String) {
        _viewModel = StateObject(wrappedValue: WishlistDetailViewModel(wishlistId: wishlistId))
    }

    var body: some View {
        List {
            if let wishlist = viewModel.wishlist, viewModel.isMine {
                Section {
                    Toggle("Visible to the family", isOn: Binding(
                        get: { wishlist.isVisibleToFamily },
                        set: { viewModel.setVisibleToFamily($0) }
                    ))
                } footer: {
                    Text("Family members can claim things they're getting you. You won't see what's been claimed.")
                }
            }
            Section {
                ForEach(viewModel.wishlist?.items ?? []) { item in
                    ItemRow(
                        item: item,
                        isMine: viewModel.isMine,
                        onEdit: { editing = .existing(item) },
                        onClaim: { viewModel.claim(item) },
                        onRelease: { viewModel.release(item) }
                    )
                    .swipeActions {
                        if viewModel.isMine {
                            Button("Delete", role: .destructive) { viewModel.delete(item) }
                        }
                    }
                }
            }
        }
        .overlay {
            if let wishlist = viewModel.wishlist, wishlist.items?.isEmpty ?? true {
                ContentUnavailableView(
                    "Nothing here yet", systemImage: "gift",
                    description: Text(viewModel.isMine
                        ? "Add things you'd like with the + button."
                        : "\(wishlist.user.name) hasn't added anything."))
            }
        }
        .navigationTitle(viewModel.wishlist?.title ?? "")
        .toolbar {
            if viewModel.isMine {
                Button { editing = .new } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add item")
                    .accessibilityIdentifier("wishlist.add")
            }
        }
        .sheet(item: $editing) { target in
            ItemEditor(target: target, onSave: viewModel.save, onDelete: viewModel.delete)
        }
        .errorAlert($viewModel.error)
        .onChange(of: viewModel.gone) { _, gone in if gone { dismiss() } }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

private struct ItemRow: View {
    let item: WishlistItem
    let isMine: Bool
    let onEdit: () -> Void
    let onClaim: () -> Void
    let onRelease: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name).font(.headline)
                Spacer()
                if let price = item.price { Text("£\(price)").font(.headline) }
            }
            let details = [item.priority == .medium ? nil : item.priority.label, item.notes.flatMap { $0.isEmpty ? nil : $0 }]
                .compactMap { $0 }
            if !details.isEmpty {
                Text(details.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack {
                if let link = item.link {
                    Link("View online", destination: link).font(.subheadline)
                }
                Spacer()
                // The owner sees no claim controls and no claim state.
                if !isMine { claimControl }
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { if isMine { onEdit() } }
    }

    @ViewBuilder
    private var claimControl: some View {
        if item.claimedByMe == true {
            Button("Claimed by you · Release", action: onRelease)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("release.\(item.name)")
        } else if item.isClaimed == true {
            Text("Claimed by \(item.claimedByName ?? "someone")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            Button("Claim", action: onClaim)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("claim.\(item.name)")
        }
    }
}

private struct ItemEditor: View {
    enum Target: Identifiable {
        case new
        case existing(WishlistItem)

        var id: String {
            if case .existing(let item) = self { return item.id }
            return "new"
        }
    }

    let target: Target
    let onSave: (WishlistItem?, WishlistItemRequest) -> Void
    let onDelete: (WishlistItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var price = ""
    @State private var url = ""
    @State private var notes = ""
    @State private var priority = WishlistItem.Priority.medium
    @State private var confirmingDelete = false

    private var existing: WishlistItem? {
        if case .existing(let item) = target { return item }
        return nil
    }

    private var priceIsValid: Bool {
        let trimmed = price.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || (Decimal(string: trimmed).map { $0 >= 0 } ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("What is it?", text: $name)
                    .accessibilityIdentifier("wishItem.name")
                HStack {
                    Text("£")
                    TextField("Price", text: $price).keyboardType(.decimalPad)
                }
                TextField("Link", text: $url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Notes (size, colour…)", text: $notes, axis: .vertical)
                Picker("How much?", selection: $priority) {
                    ForEach(WishlistItem.Priority.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                if existing != nil {
                    Section {
                        Button("Delete Item", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(existing, WishlistItemRequest(
                            name: name.trimmingCharacters(in: .whitespaces),
                            url: url.trimmingCharacters(in: .whitespaces),
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            price: price.trimmingCharacters(in: .whitespaces),
                            priority: priority))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || !priceIsValid)
                    .accessibilityIdentifier("wishItem.save")
                }
            }
            .confirmationDialog("Delete this item from your wishlist?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Item", role: .destructive) {
                    if let existing { onDelete(existing) }
                    dismiss()
                }
            }
            .onAppear {
                guard let existing else { return }
                name = existing.name
                price = existing.price ?? ""
                url = existing.url ?? ""
                notes = existing.notes ?? ""
                priority = existing.priority
            }
        }
    }
}
