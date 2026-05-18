# AgriLink (CAP)

**Collective Action Program** — a mobile app for regenerative agriculture. It helps farmers and farm communities connect, share knowledge, trade equipment, plan events, collaborate on goals, and message each other.

This repo also includes a **web dashboard** (Next.js) for staff and power users, plus **Supabase** backend config (database migrations and edge functions).

**Last updated:** May 2026 · App version `1.0.7+18`

---

## What’s in this repo

| Part | Folder | What it is |
|------|--------|------------|
| Mobile app | `lib/`, `android/`, `ios/` | Flutter app (iOS & Android) |
| Web dashboard | `dashboard/` | Next.js admin / web companion |
| Backend | `supabase/` | SQL migrations, edge functions (auth helpers, push, admin) |

The mobile app is the main product. New accounts are created on mobile; the dashboard is mainly for managing content and admin work on the web.

---

## Features (mobile)

- **Community feed** — posts, likes, comments, sharing
- **Exchange hub & marketplace** — listings, tags, sorting
- **Events** — create, register, share
- **Collaboration** — goals & milestones, reciprocity ring (asks/offers), future farm visualizations, workshops
- **Polls** — create and vote in community polls
- **Chat** — direct messaging, share posts/events in chat
- **Farm network** — farm directory and detailed farm profiles
- **Resources** — workshops, knowledge repository (file uploads)
- **Search** — find people and content
- **Notifications** — in-app + optional push (Firebase)
- **Profiles** — edit profile, followers/following, settings, privacy & terms

---

## Prerequisites

Before you start, install:

- [Flutter](https://docs.flutter.dev/get-started/install) **3.5+** (`flutter doctor` should look mostly green)
- **Xcode** (for iOS Simulator or a physical iPhone)
- **Android Studio** (optional, for Android emulator or Play builds)
- **CocoaPods** (for iOS): `sudo gem install cocoapods` if needed
- A [Supabase](https://supabase.com) project (URL + anon key)

For the **web dashboard** only: **Node.js 18+**

---

## First-time setup (mobile)

### 1. Clone and open the project

```bash
git clone <your-repo-url>
cd agrilink
```

### 2. Environment variables (required)

Secrets are **not** in the repo. Copy the example file and add your Supabase credentials:

```bash
cp .env.example .env
```

Edit `.env`:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-public-key
```

Get both from Supabase → **Project Settings** → **API** (use the **anon / public** key, never the service role key).

### 3. Install Flutter dependencies

From the project root:

```bash
flutter clean
flutter pub get
```

`flutter clean` clears old build cache — useful after cloning or when something feels “stuck.”

### 4. iOS only — install pods

```bash
cd ios
pod install
cd ..
```

### 5. Run the app

List devices:

```bash
flutter devices
```

Run (pick a device id if you have several):

```bash
flutter run
# example:
# flutter run -d ios
# flutter run -d <device-id>
```

---

## Release builds

### Android (Google Play)

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Play Store package id: `com.agrilink.cap`

For signed release builds you may need `android/key.properties` and a keystore — set that up in Android Studio or your CI before uploading.

### iOS (App Store / TestFlight)

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios --release
```

Then open **`ios/Runner.xcworkspace`** in Xcode, set your signing team, and **Product → Archive**.

---

## Tests & checks

```bash
flutter analyze
flutter test
```

Tests load `.env.test` (placeholder values, safe to commit). Your real `.env` is only for local runs.

---

## Web dashboard (optional)

The dashboard lives in `dashboard/`. It uses the **same Supabase project** as the mobile app.

```bash
cd dashboard
cp .env.example .env.local
# edit .env.local — same SUPABASE_URL and anon key as mobile
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

Sign in with an account that already exists in Supabase (usually created on mobile). Optional env vars for admin access are documented in `dashboard/.env.example` if you add them later.

---

## Backend (Supabase)

- Database changes live in **`supabase/migrations/`** — apply them to your Supabase project in order (Supabase CLI or SQL editor).
- Edge functions are under **`supabase/functions/`** (password reset, push notifications, admin tools, account delete).

You need a Supabase project that matches these migrations. If you’re setting up a **new** empty project, plan time to run migrations and configure storage buckets / RLS — the app expects the schema those files define.

---

## Push notifications (optional)

The app supports Firebase Cloud Messaging. These files are **gitignored** and must be added locally:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Without them the app still runs; push just won’t work until you run `flutterfire configure` or copy files from your Firebase project (`ivey-cap` or your own).

---

## Project layout (short)

```
agrilink/
├── lib/                 # Flutter app source
│   ├── core/            # theme, routing, config
│   ├── features/        # screens by feature (auth, chat, events, …)
│   ├── providers/       # app state (Provider)
│   └── services/        # API / Supabase helpers
├── android/ / ios/      # native projects
├── dashboard/           # Next.js web app
├── supabase/            # migrations & edge functions
├── .env.example         # copy → .env (not committed)
└── pubspec.yaml         # Flutter dependencies & version
```

---

## Public repo note

Do **not** commit `.env`, `dashboard/.env.local`, Firebase plist/json, or signing keys. If keys were ever committed, rotate them in the Supabase / Firebase consoles before going public.

---

## License

Part of a research initiative for sustainable agriculture. See repository settings or your team for license terms.
