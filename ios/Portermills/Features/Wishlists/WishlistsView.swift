import SwiftUI

struct WishlistsView: View {
    @StateObject private var viewModel = WishlistsViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.wishlists) { wishlist in
                NavigationLink(value: wishlist.id) {
                    Label {
                        VStack(alignment: .leading) {
                            Text(wishlist.title)
                            Text(itemCountLabel(wishlist.itemCount)).font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: wishlist.isMine && !wishlist.isVisibleToFamily ? "eye.slash" : "gift")
                    }
                }
                .accessibilityIdentifier("wishlist.\(wishlist.title)")
            }
            .navigationTitle("Wishlists")
            .navigationDestination(for: String.self) { id in WishlistDetailView(wishlistId: id) }
            .toolbar { AccountMenu() }
            .errorAlert($viewModel.error)
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }
}
