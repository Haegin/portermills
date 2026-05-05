import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            ListsView()
                .tabItem { Label("Lists", systemImage: "checklist") }

            WishlistsView()
                .tabItem { Label("Wishlists", systemImage: "gift") }
        }
    }
}
