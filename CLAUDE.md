# Portermills Family App

A private family app with a shared calendar, lists (shopping + packing), and wishlists.
Built as a playground — features may be unrelated to one another.

## Repository Layout

```
portermills/
├── mobile/     # React Native app (iOS + Android)
└── server/     # Elixir/Phoenix backend
```

## Architecture

### Mobile — React Native (TypeScript)

**Why React Native**: native UI components on both platforms (not a webview, not Flutter's
custom renderer), single codebase, easy platform-specific overrides via `.ios.ts` /
`.android.ts` file extensions. iOS-only or Android-only features live in platform-specific
files; the other platform simply doesn't ship them.

**Key libraries**:
- Navigation: `@react-navigation/native` (stack + bottom tabs)
- Server state / fetching: `@tanstack/react-query`
- Client state: `zustand`
- Real-time: Phoenix WebSocket via `@craftzing/phoenix-js` or a thin wrapper
- Local storage: `react-native-mmkv`
- Date handling: `date-fns`

**Directory structure**:
```
mobile/src/
├── api/            # API client, Phoenix socket setup
├── components/     # Shared UI primitives
├── hooks/          # Shared hooks
├── navigation/     # Root navigator and screen definitions
├── utils/          # Pure helpers
└── features/
    ├── auth/       # Login, token storage, user context
    ├── calendar/   # Shared family calendar
    ├── lists/      # Shopping + packing lists (shared domain)
    └── wishlists/  # Per-person wishlists (SEPARATE domain)
```

Each feature folder follows this convention:
```
features/calendar/
├── screens/        # React Native screens
├── components/     # Feature-local components
├── hooks/          # Feature-local hooks
├── api.ts          # tRQ query/mutation definitions for this feature
└── types.ts        # TypeScript types for this feature
```

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
│   ├── accounts/           # Users, families, tokens
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

Data lives in `wishlists` + `wishlist_items` tables in the `wishlists` context.
No code is shared with the `lists` context.

## Data Model (summary)

### Accounts
- `families` — (id, name)
- `users` — (id, family_id, name, email, role: admin|member)
- `device_tokens` — (id, user_id, token, device_name, last_seen_at)

### Calendar
- `calendar_events` — (id, family_id, created_by_id, title, description, starts_at, ends_at, all_day, recurrence_rule)

### Lists
- `lists` — (id, family_id, type: shopping|packing, name, archived)
- `list_items` — (id, list_id, name, checked, position, added_by_id)
- `packing_templates` — (id, family_id, name, occasion)
- `packing_template_items` — (id, template_id, name, position)

### Wishlists (separate schema prefix: `wl_`)
- `wl_wishlists` — (id, user_id, is_visible_to_family)
- `wl_items` — (id, wishlist_id, name, url, notes, price, priority)
- `wl_claims` — (id, item_id, claimed_by_id) — hidden from wishlist owner

## App Distribution

**Android**: Firebase App Distribution (recommended) or direct APK sideload.
Build: `cd mobile/android && ./gradlew bundleRelease`

**iOS**: TestFlight (requires Apple Developer Program, $99/yr).
Alternative without a developer account: AltStore / SideStore (re-signs every 7 days).
Build: Xcode → Product → Archive → Distribute

## Development

### Mobile
```bash
cd mobile
npm install
# iOS
npx pod-install ios
npx react-native run-ios
# Android
npx react-native run-android
```

### Server
```bash
cd server
mix deps.get
mix ecto.setup   # creates DB, runs migrations, seeds
mix phx.server   # starts on localhost:4000
```

### Environment
Copy `server/.env.example` → `server/.env` and fill in `DATABASE_URL`, `SECRET_KEY_BASE`,
`GUARDIAN_SECRET`.

## Conventions

- All new features go in their own `features/<name>` folder in mobile, and their own
  context in `server/lib/portermills/<name>/`.
- Platform-specific mobile code uses `.ios.ts` / `.android.ts` suffixes — the other
  platform's bundle simply won't include it.
- Web-accessible features (visible to non-family users) are built in LiveView under
  `portermills_web/live/` and protected by separate auth logic.
- Wishlists data MUST NOT be imported or referenced from the lists context, and vice versa.
