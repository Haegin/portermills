# Portermills Family App

A private family app with a shared calendar, lists (shopping + packing), and wishlists.
Built as a playground — features may be unrelated to one another.

## Repository Layout

```
portermills/
├── ios/        # Native iOS app (Swift/SwiftUI)
├── android/    # Native Android app (Kotlin/Jetpack Compose)
└── server/     # Elixir/Phoenix backend
```

## Architecture

### iOS — Swift / SwiftUI

**Why native iOS**: full access to Apple platform APIs, native SwiftUI components,
no bridge overhead. iOS-only features are built here and simply don't exist in Android.

**Key patterns**:
- UI: SwiftUI views + `@StateObject` / `@ObservedObject` ViewModels
- Networking: `URLSession` via `APIClient` (snake_case ↔ camelCase via `JSONDecoder` strategy)
- Real-time: `PhoenixSocket` (thin `URLSessionWebSocketTask` wrapper)
- Auth state + token: `AuthStore` (backed by Keychain)
- No external dependencies required for the base app

**Directory structure**:
```
ios/Portermills/
├── PortermillsApp.swift     # @main entry point
├── ContentView.swift        # Root TabView (authenticated)
├── Services/
│   ├── APIClient.swift      # HTTP client (get/post/patch/delete)
│   ├── PhoenixSocket.swift  # WebSocket client (auto-reconnects)
│   └── AuthStore.swift      # Token + user state, Keychain persistence
└── Features/
    ├── Auth/
    │   ├── LoginView.swift
    │   └── Models.swift
    ├── Calendar/
    │   ├── CalendarView.swift
    │   ├── CalendarViewModel.swift
    │   └── Models.swift
    ├── Lists/
    │   ├── ListsView.swift
    │   ├── ListsViewModel.swift
    │   └── Models.swift
    └── Wishlists/
        ├── WishlistsView.swift
        ├── WishlistsViewModel.swift
        └── Models.swift
```

**Project setup** (first time):
1. Open Xcode → File → New Project → App
2. Set Bundle ID `app.portermills`, SwiftUI interface, Swift language
3. Replace generated files with the source files in `ios/Portermills/`
4. No SPM packages needed for the base app

**Distribution**: TestFlight (requires Apple Developer Program, $99/yr).
Alternative without a developer account: AltStore / SideStore (re-signs every 7 days).

---

### Android — Kotlin / Jetpack Compose

**Why native Android**: Jetpack Compose is first-class on Android, Hilt for DI is
well-supported, all Android-specific features available without bridges.

**Key patterns**:
- UI: Jetpack Compose + Material 3
- Architecture: MVVM with `ViewModel` + `StateFlow`
- DI: Hilt
- Networking: OkHttp (raw, no Retrofit — keeps it lean)
- Serialization: `kotlinx.serialization`
- Auth state: `AuthDataStore` (backed by Jetpack DataStore)
- Real-time: `PhoenixSocket` (OkHttp WebSocket wrapper)
- Navigation: Compose Navigation

**Directory structure**:
```
android/app/src/main/java/app/portermills/
├── MainActivity.kt
├── PortermillsApp.kt          # Hilt @HiltAndroidApp
├── navigation/
│   └── AppNavigation.kt       # NavHost + BottomNavigationBar
├── data/
│   ├── api/
│   │   ├── ApiClient.kt       # HTTP client (OkHttp)
│   │   └── AuthDataStore.kt   # DataStore token persistence
│   └── socket/
│       └── PhoenixSocket.kt   # WebSocket client
└── features/
    ├── auth/
    │   ├── AuthViewModel.kt
    │   ├── LoginScreen.kt
    │   └── Models.kt
    ├── calendar/
    │   ├── CalendarViewModel.kt
    │   ├── CalendarScreen.kt
    │   └── Models.kt
    ├── lists/
    │   ├── ListsViewModel.kt
    │   ├── ListsScreen.kt
    │   └── Models.kt
    └── wishlists/
        ├── WishlistsViewModel.kt
        ├── WishlistsScreen.kt
        └── Models.kt
```

**Distribution**: Firebase App Distribution (recommended) or direct APK sideload.
Build: `cd android && ./gradlew bundleRelease`

---

### Server — Elixir/Phoenix

**Key libraries**:
- Phoenix (HTTP + Channels + LiveView)
- Ecto + Postgrex (PostgreSQL)
- Guardian (JWT auth)
- Jason (JSON)

**Directory structure**:
```
server/lib/
├── portermills/            # Business logic (contexts)
│   ├── accounts/           # Users, families, magic tokens
│   ├── calendar/           # Calendar events
│   ├── lists/              # Shopping + packing lists
│   └── wishlists/          # Wishlists (separate context)
└── portermills_web/        # HTTP + WebSocket layer
    ├── channels/           # Phoenix Channels (real-time)
    ├── controllers/        # REST endpoints
    └── live/               # LiveView (web-facing features)
```

## Feature Domains

### Calendar
Shared family calendar. Events broadcast in real-time via Phoenix Channel
(`family:<id>:calendar`). All family members see changes immediately.

### Lists
Shopping list and packing lists (multiple named packing lists for different occasions).
Real-time sync via Phoenix Channel (`family:<id>:lists`). Checking off an item on one
device instantly updates others.

Data lives in `lists` + `list_items` tables within the `lists` context. Packing list
templates are stored separately from live list instances.

### Wishlists
**Intentionally separate** from lists — different UX, different data model, different
Channel. Each family member has their own wishlist. Others can view and mark items as
claimed/purchased without the wishlist owner seeing (for surprise gifts).

Data lives in `wl_wishlists` + `wl_items` + `wl_claims` tables in the `wishlists` context.
No code is shared with the `lists` context.

## Data Model (summary)

### Accounts
- `families` — (id, name)
- `users` — (id, family_id, name, email, role: admin|member)
- `magic_tokens` — (id, user_id, token, expires_at, used_at)

### Calendar
- `calendar_events` — (id, family_id, created_by_id, title, description, starts_at, ends_at, all_day, recurrence_rule)

### Lists
- `lists` — (id, family_id, type: shopping|packing, name, archived)
- `list_items` — (id, list_id, name, checked, position, added_by_id)

### Wishlists (separate schema prefix: `wl_`)
- `wl_wishlists` — (id, user_id, is_visible_to_family)
- `wl_items` — (id, wishlist_id, name, url, notes, price, priority)
- `wl_claims` — (id, item_id, claimed_by_id) — hidden from wishlist owner

## Development

### Server
```bash
cd server
mix deps.get
mix ecto.setup   # creates DB, runs migrations, seeds
mix phx.server   # starts on localhost:4000
```

### iOS
Open `ios/Portermills.xcodeproj` in Xcode, select a simulator, and press Run.
The app points to `http://localhost:4000` in debug builds.

### Android
```bash
cd android
./gradlew installDebug   # installs on connected device/emulator
```
The app points to `http://10.0.2.2:4000` (localhost from the Android emulator).

### Environment
Copy `server/.env.example` → `server/.env` and fill in `DATABASE_URL`, `SECRET_KEY_BASE`,
`GUARDIAN_SECRET`.

## Conventions

- All new server-side features go in their own context under `server/lib/portermills/<name>/`.
- iOS features live in `ios/Portermills/Features/<Name>/`; Android features in
  `android/.../features/<name>/`. Feature structure is ViewModel + Screen(s) + Models.
- Android-only features simply don't have a counterpart in `ios/`, and vice versa.
- Web-accessible features (visible to non-family users) are built in LiveView under
  `portermills_web/live/` and protected by separate auth logic.
- Wishlists data MUST NOT be imported or referenced from the lists context, and vice versa.
- API field names are snake_case on the server. iOS uses `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`.
  Android uses `@SerialName` annotations on model fields.
