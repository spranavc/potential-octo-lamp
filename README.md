# Boldr

> Track your climbs. Get better. Be Boldr.

Boldr is a bouldering progress tracker — log sessions, track grade progression, manage gyms and projects, and visualize your climbing analytics. Built with Flutter, backed by Supabase.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.44+
- [Git](https://git-scm.com/)
- A code editor (VS Code recommended)

### Setup

```bash
# 1. Clone the repo
git clone https://github.com/spranavc/potential-octo-lamp.git
cd potential-octo-lamp

# 2. Make scripts executable
chmod +x scripts/*.sh deploy-prod deploy-dev cleanup-dev

# 3. Install dependencies
flutter pub get

# 3. Generate Drift database code
dart run build_runner build

# 4. Verify everything works
flutter analyze
flutter test
```

### Run Locally

```bash
# Windows desktop (phone-sized 390×844 window)
flutter run -d windows

# Chrome / Web
flutter run -d chrome
```

### Simulate Production Locally (Release Build)

Always test with a **release build** to match what GitHub Pages serves:

```bash
# Build and serve — simulates deployed gh-pages
deploy-dev

# Clean up when done
cleanup-dev
```

This builds the web app in release mode and serves it at `http://localhost:8081`. Ctrl+C to stop.

### Deploy to Production

```bash
deploy-prod -cm "your commit message"
```

This commits pending changes, pushes to `main`, builds the web app, and force-pushes to `gh-pages`. The app is live at [spranavc.github.io/potential-octo-lamp](https://spranavc.github.io/potential-octo-lamp/).

If all changes are already committed, you can omit `-cm`.

## Project Structure

```
lib/
├── main.dart                          # Entry point
├── app.dart                           # MaterialApp.router
├── supabase_init.dart                 # Supabase initialization
├── core/
│   ├── routing/app_router.dart        # GoRouter + auth redirect
│   └── theme/app_theme.dart           # Material 3 theme
├── data/
│   ├── database/                      # Drift tables, DAOs, platform factories
│   ├── providers/                     # Riverpod providers for DB and repos
│   └── repositories/                  # Data access layer
├── domain/services/                   # Business logic (auth, sync, analytics, etc.)
├── features/
│   ├── session_log/                   # Tab 1 — Log sessions
│   ├── analytics/                     # Tab 2 — Charts and insights
│   ├── gyms/                          # Tab 3 — Gym directory + management
│   ├── projects/                      # Project tracking
│   ├── profile/                       # Auth screens + profile
│   └── sync/                          # Supabase sync providers
└── shared/utils/                      # Shared helpers
```

## Tech Stack

| Layer | Tech |
|---|---|
| Framework | Flutter 3.44.2 |
| Language | Dart 3.12.2 |
| State | Riverpod 2.6.1 |
| Local DB | Drift (SQLite) 2.33.0 |
| Remote DB | Supabase (PostgreSQL) |
| Auth | Supabase Auth (email/password) |
| Router | GoRouter 14.8.1 |
| Charts | fl_chart 0.70.2 |
| CI/CD | GitHub Actions + Codemagic |

## Testing

```bash
# Run all tests
flutter test

# Run a specific test file
flutter test test/features/gyms/gym_providers_test.dart
```

Tests use an in-memory SQLite database via `createTestDatabase()` from `test/data/test_helpers.dart`. Supabase is mocked with a localhost URL.

### Web Testing with Playwright

```bash
# Build and serve locally first
deploy-dev

# Then use the Playwright MCP tools in Claude Code
# Or write standalone Playwright scripts against http://localhost:8081
```

## Common Commands

```bash
flutter pub get                          # Install dependencies
dart run build_runner build             # Generate Drift code
flutter run -d windows                   # Windows desktop
flutter run -d chrome                    # Chrome
flutter analyze                          # Static analysis
flutter test                             # Run tests
bash scripts/reset_db.sh                # Reset local database
deploy-dev                               # Build + serve locally
cleanup-dev                              # Stop server + clean build
deploy-prod -cm "message"               # Deploy to production
```

## Database Migrations

After changing `lib/data/database/tables.dart`:

1. Edit `lib/data/database/database.dart` — bump `schemaVersion`, add migration in `onUpgrade`
2. Run `dart run build_runner build`
3. Run `flutter test` — all tests must pass

Migrations must be backward-compatible: new columns must be nullable or have defaults. Never remove a column without a multi-step migration.

## Supabase Setup

The app connects to a Supabase project for auth, data sync, and the gym directory. Remote tables are created via SQL (see `docs/` for schema scripts). Row Level Security ensures users can only access their own data.
