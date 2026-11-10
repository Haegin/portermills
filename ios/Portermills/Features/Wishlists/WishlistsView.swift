import SwiftUI

struct WishlistsView: View {
    @StateObject private var vm = WishlistsViewModel()

    var body: some View {
        NavigationStack {
            List(vm.wishlists) { wishlist in
                NavigationLink {
                    WishlistDetailView(wishlist: wishlist, vm: vm)
                } label: {
                    Text(wishlist.user?.name ?? "Wishlist")
                }
            }
            .navigationTitle("Wishlists")
            .task { await vm.load() }
        }
    }
}

struct WishlistDetailView: View {
    let wishlist: Wishlist
    @ObservedObject var vm: WishlistsViewModel
    @EnvironmentObject private var authStore: AuthStore

    private var items: [WishlistItem] { vm.itemsByWishlist[wishlist.id] ?? [] }
    private var isOwnWishlist: Bool { wishlist.userId == authStore.currentUser?.id }

    var body: some View {
        List(items) { item in
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name).font(.headline)
                    if let price = item.price {
                        Text(price, format: .currency(code: "USD")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !isOwnWishlist {
                    Button {
                        Task {
                            item.isClaimed
                                ? await vm.unclaimItem(item)
                                : await vm.claimItem(item)
                        }
                    } label: {
                        Image(systemName: item.isClaimed ? "gift.fill" : "gift")
                            .foregroundStyle(item.isClaimed ? .green : .secondary)
                    }
                }
            }
        }
        .navigationTitle(wishlist.user?.name.appending("'s Wishlist") ?? "Wishlist")
        .task { await vm.loadItems(for: wishlist) }
    }
}
