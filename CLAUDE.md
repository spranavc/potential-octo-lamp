# CLAUDE.md

> Last updated: 2026-06-21

## What This Project Is

**ClimbApp** — bouldering progress tracker. Log climbs, track grade progression, manage gyms and projects, visualize analytics.

| Layer | Tech | Version |
|---|---|---|
| Framework | Flutter | 3.44.2 |
| Language | Dart | 3.12.2 |
| State | Riverpod | 2.6.1 |
| Local DB | Drift (SQLite) | 2.33.0 |
| Remote DB | Supabase (PostgreSQL) | supabase_flutter ^2.15.0 |
| Router | GoRouter | 14.8.1 |
| Charts | fl_chart | 0.70.2 |
| CI/CD | GitHub Actions + Codemagic | — |

**Target platforms:** iOS (primary, via Codemagic CI/CD), Windows desktop (dev/testing, phone-sized 390×844 window), Chrome (web). Web deploys to GitHub Pages.

## Project Structure

```
lib/
├── main.dart                          # Entry — inits Supabase (all platforms), creates DB, runs app
├── app.dart                           # MaterialApp.router widget
├── supabase_init.dart                 # Supabase.initialize() helper
│
├── core/
│   ├── routing/app_router.dart        # GoRouter with StatefulShellRoute + auth redirect
│   └── theme/app_theme.dart           # Material 3 theme
│
├── data/
│   ├── database/
│   │   ├── tables.dart                # 9 Drift table definitions
│   │   ├── database.dart              # @DriftDatabase + inline DAOs + schema v3 + migrations
│   │   ├── database.g.dart            # GENERATED (gitignored) — codegen output
│   │   ├── connection.dart            # Conditional import: factory_io vs factory_stub
│   │   ├── database_factory_io.dart   # Native: LazyDatabase → sqlite3_flutter_libs
│   │   └── database_factory_stub.dart # Web: WasmDatabase with WebDatabase fallback
│   ├── providers/
│   │   ├── database_provider.dart     # AppDatabase provider (+ stub)
│   │   ├── database_provider_impl.dart
│   │   └── repository_providers.dart  # Gym, Session, Climb, Tag, Project repo providers
│   └── repositories/
│       ├── gym_repository.dart
│       ├── session_repository.dart
│       ├── climb_repository.dart
│       ├── tag_repository.dart
│       └── project_repository.dart
│
├── domain/services/
│   ├── auth_service.dart              # Supabase auth wrapper (signUp/signIn/signOut/currentUser)
│   ├── session_service.dart           # Orchestrates session start/end/log across repos
│   ├── analytics_service.dart         # Grade distribution, send rate, heatmaps, etc.
│   ├── performance_service.dart       # Session-over-session performance analysis
│   └── export_service.dart            # CSV export
│
├── features/
│   ├── session_log/                   # TAB 1 — "Log"
│   │   ├── providers/
│   │   │   ├── active_session_provider.dart   # StateNotifier — live session state machine
│   │   │   ├── session_list_provider.dart
│   │   │   └── session_detail_provider.dart
│   │   ├── screens/
│   │   │   ├── session_log_home.dart          # Start new / resume / history list
│   │   │   ├── active_session_screen.dart     # THE logging screen (grade, tags, RPE, send/fail)
│   │   │   ├── session_summary_screen.dart    # Post-session stats
│   │   │   ├── session_detail_screen.dart     # View/edit past session climbs
│   │   │   └── project_picker_dialog.dart     # Multi-project selector
│   │   └── widgets/                           # attempts_counter, grade_picker, rpe_slider, tag_chips, swipe_card
│   │
│   ├── analytics/                    # TAB 2 — "Analytics"
│   │   ├── providers/analytics_providers.dart
│   │   ├── screens/analytics_dashboard.dart
│   │   └── widgets/                  # grade_pyramid, send_rate, activity_heatmap, hardest_sends, etc.
│   │
│   ├── gyms/                         # TAB 3 — "Gyms"
│   │   ├── providers/gym_providers.dart
│   │   ├── screens/gyms_list_screen.dart
│   │   ├── screens/gym_detail_screen.dart  # Gym info + active/completed projects + session history
│   │   └── widgets/gym_card.dart
│   │
│   ├── projects/                     # Accessible via session-log sub-route
│   │   ├── providers/project_providers.dart
│   │   ├── screens/projects_list_screen.dart
│   │   ├── screens/project_detail_screen.dart
│   │   └── widgets/                  # project_card, project_progress_bar
│   │
│   ├── profile/                      # Auth screens
│   │   ├── providers/auth_providers.dart
│   │   └── screens/                  # login_screen, signup_screen, email_verification_screen
│   │
│   └── settings/                     # TAB 4 — "Settings"
│       └── screens/settings_screen.dart  # Export data, delete all data, about
│
└── shared/utils/time_format.dart
```

**Data flow:** UI → Riverpod Provider → Domain Service → Repository → Drift DAO → SQLite

## Database Schema (Drift, schema v3)

9 tables in `lib/data/database/tables.dart`:

| Table | Key Columns | Notes |
|---|---|---|
| Gyms | id, name, createdAt | User's climbing gyms |
| Walls | id, gymId (FK), name | Walls within a gym |
| GymColors | id, gymId (FK), colorName, colorHex, gradeSystem, gradeValue | Hold-color→grade mapping (unused in UI) |
| Sessions | id, gymId (FK), wallId (nullable FK), startedAt, endedAt, notes | A logging session |
| Climbs | id, sessionId (FK), gradeSystem, gradeValue, sent, attemptNumber, problemNumber, rpe, completionPercent, notes, loggedAt | Individual climb attempts |
| Tags | id, name (unique) | Climb style tags |
| ClimbTags | climbId (FK), tagId (FK) | Many-to-many climb↔tag |
| Projects | id, gymId (FK), name, gradeSystem, gradeValue, description, status, startedAt, completedAt | Grade projects |
| ProjectClimbs | projectId (FK), climbId (FK) | Many-to-many project↔climb |

Migrations:
- v1→v2: added `attemptNumber`, `problemNumber` to Climbs
- v2→v3: added `completionPercent` (nullable int) to Climbs

Seed data: 5 default tags on create — crimpy, dynamic, slopey, overhang, slab.

## Routing (GoRouter)

```
/login                    → LoginScreen (no bottom nav)
/signup                   → SignUpScreen (no bottom nav)
/verify-email/:email      → EmailVerificationScreen (no bottom nav)

StatefulShellRoute (4 bottom tabs):
  Tab 0 "Log"      /session-log          → SessionLogHome
                   /session-log/active   → ActiveSessionScreen
                   /session-log/summary  → SessionSummaryScreen
                   /session-log/projects → ProjectsListScreen
                   /session-log/projects/:projectId → ProjectDetailScreen
                   /session-log/:sessionId → SessionDetailScreen

  Tab 1 "Analytics" /analytics           → AnalyticsDashboard

  Tab 2 "Gyms"      /gyms                → GymsListScreen
                   /gyms/:gymId          → GymDetailScreen

  Tab 3 "Settings"  /settings            → SettingsScreen
```

**Auth redirect:**
- `initialLocation: '/session-log'`
- Checks `Supabase.instance.client.auth.currentSession`
- No session → redirect to `/login`
- Has session + on auth route → redirect to `/session-log`
- Wrapped in try/catch for web safety

**Critical:** Literal paths must come before parameterized paths. `projects` before `:sessionId`.

## Key Patterns

### Supabase on All Platforms
`initSupabase()` is called on all platforms including web. The passkeys JS bundle in `web/index.html` is required by the transitive `passkeys_web` dependency from `supabase_flutter`.

### Conditional Imports (Platform DB)
```dart
// connection.dart
import 'database_factory_stub.dart'
    if (dart.library.io) 'database_factory_io.dart';
```
- IO: NativeDatabase with `sqlite3_flutter_libs` (Windows, iOS, Android)
- Stub: WasmDatabase with `WebDatabase` fallback (web)

### Repository Pattern
All data access goes through repositories (not DAOs directly). Repositories are plain Dart classes injected via Riverpod providers.

### Active Session State Machine
`ActiveSessionNotifier` (StateNotifier) in `active_session_provider.dart`:
- `start()` → creates DB session row, sets isActive=true
- `logAttempt()` → persists climb immediately to DB, appends to in-memory list
- `nextProblem()` / `nextAttempt()` / `resumeProblem()` → counter management
- `end()` → sets endedAt, invalidates related providers. If totalCount==0, calls cancel() instead.
- `cancel()` → deletes the session row (for empty sessions)

### Riverpod Invalidation
After any write, invalidate the relevant read providers:
```dart
ref.invalidate(sessionListProvider);
ref.invalidate(gymSessionsProvider(gymId));
```

### Completion < 100% Guard
Tapping "Send" with completionPercent < 100% shows a confirmation dialog. If user doesn't adjust to 100%, it logs as a FAIL.

## Web Deployment & Testing

### Simulating Production Locally (Release Build)
Always test with a **release build** (not debug mode) to match what GitHub Pages serves:

```bash
# Build (same output that gh-pages serves)
MSYS_NO_PATHCONV=1 flutter build web --base-href "/"

# Serve locally for Playwright testing
python -m http.server 8081 -d build/web
```

Then point Playwright at `http://localhost:8081`. The release build loads instantly (single `main.dart.js`) vs debug mode which loads 945 separate scripts.

### Playwright MCP (Ad-hoc Visual Testing)
The Playwright MCP server is configured in `.mcp.json` for browser automation from Claude Code.

**iPhone-sized viewport (390×844):** Resize the browser before taking snapshots:
```
"Resize the browser to 390x844"
```

**Key Playwright commands from Claude Code:**
| Instruction | Action |
|---|---|
| "Navigate to localhost:8081" | `browser_navigate` |
| "Snapshot the page" | `browser_snapshot` (accessibility tree) |
| "Screenshot" | `browser_take_screenshot` |
| "Click the Login button" | `browser_click` |
| "Type into Email field" | `browser_type` |
| "Resize to 390x844" | `browser_resize` |
| "Check console errors" | `browser_console_messages` |

### Debug Overlay Dismissal
In debug mode, Flutter shows an "Enable accessibility" overlay. Dismiss it with:
```
"Run JS: document.querySelector('flt-semantics-placeholder')?.click()"
```

### Deploying to GitHub Pages
URL: `https://spranavc.github.io/potential-octo-lamp/`
Script: `bash scripts/deploy_web.sh` — builds, creates gh-pages branch, force-pushes.
Uses `--base-href "/potential-octo-lamp/"` matching the repo name.

## Supabase Config

| Setting | Value |
|---|---|
| Auth | email/password |
| Init file | `lib/supabase_init.dart` — called on all platforms |
| Keys | Stored in `lib/supabase_init.dart` |
| Web safety | Passkeys JS bundle in `web/index.html` (required by transitive passkeys_web dep); router wraps Supabase access in try/catch |

## Common Commands

```bash
flutter pub get                          # Install deps
dart run build_runner build             # Generate Drift code (database.g.dart)
flutter run -d windows                   # Windows desktop (390×844 phone-sized window)
flutter run -d chrome                    # Chrome
flutter analyze                          # Static analysis
flutter test                             # Run tests

# Web testing (simulates deployment)
MSYS_NO_PATHCONV=1 flutter build web --base-href "/"
python -m http.server 8081 -d build/web

bash scripts/reset_db.sh                # Delete ~/Documents/climbapp.sqlite
bash scripts/setup.sh                    # Full setup: pub get → codegen → analyze → test
bash scripts/deploy_web.sh              # Build + deploy to gh-pages
```

## Testing

`test/data/test_helpers.dart` exports `createTestDatabase()` — in-memory SQLite via `NativeDatabase.memory()`. Widget tests use `SharedPreferences.setMockInitialValues({})`.

Test files: widget_test, data/database/tables_test, data/repositories/{climb,session}_repository_test, domain/services/{analytics,performance}_service_test, features/{gyms,analytics,projects}/*_test.

## Known Gotchas

1. **`database.g.dart` must exist** — always run `dart run build_runner build` after clean checkout, branch switch, or table change. It's gitignored.
2. **pubspec.lock is gitignored** — first run after clone needs `flutter pub get`.
3. **Web + Supabase** — `supabase_flutter` pulls in `passkeys_web` which needs the Corbado JS bundle in `web/index.html`. Router wraps Supabase in try/catch as second defense.
4. **Deploy script force-switches branches** — `git checkout --force` wipes uncommitted changes. Stash first.
5. **Schema migrations must be backward-compatible** — new columns must be nullable or have defaults. Never remove a column without a multi-step migration.
6. **Empty session guard** — ending session with 0 climbs calls cancel() (deletes session) instead of end().
7. **CI needs codegen** — `.github/workflows/pr-check.yml` runs `dart run build_runner build` before analyze and test.
8. **Use release build for testing** — debug mode (DDC) is slow. Use `flutter build web` + static server to match production behavior.

## Pending Work

| Item | Status |
|---|---|
| Sync infrastructure (push/pull to Supabase) | Not started |
| `userId` columns on local tables | Not started |
| Profile setup screen | Backlog |
| Structured goal tracking | Backlog |
| Google/Apple OAuth | Not started |

## Behavioral Guidelines

- **Supabase works everywhere** — `initSupabase()` runs on all platforms. The passkeys JS bundle in `web/index.html` is required.
- **Keep changes minimal** — small, focused diffs over large refactors.
- **Always run codegen after table changes** — `dart run build_runner build`.
- **Invalidate after writes** — any mutation must invalidate the relevant read providers.
- **Test with in-memory DB** — use `createTestDatabase()` from test_helpers.dart.
- **Test web changes with release build** — use `flutter build web` + static server + Playwright to verify before deploying.
- **Route literal paths first** — in GoRouter, literal paths before parameterized ones.
- **Stash before deploy** — the deploy script force-switches branches.
- **Prefer simplicity** — the user explicitly prefers simple, minimal implementations over clever abstractions.

## Commit Message Conventions

Follow [Conventional Commits](https://www.conventionalcommits.org/) (`<type>: <description>`).

### Types
| Type | When to use |
|---|---|
| `feat:` | New feature or screen |
| `fix:` | Bug fix |
| `refactor:` | Code restructuring with no behavior change |
| `chore:` | Deps, scripts, config, CI — anything not user-facing |
| `style:` | Formatting, whitespace, lint fixes |
| `test:` | Adding or updating tests |
| `docs:` | Documentation only |

### Guidelines
- **Imperative, lowercase** — `feat: add session detail screen`, not `Added session detail`
- **Keep it short** — the subject line should be under 72 characters
- **No period at the end** — `fix: resolve tag labels showing IDs`
- **Be specific** — `fix: guard Supabase.instance from LateInitializationError on web` over `fix: web crash`
- **Reference files when helpful** — `refactor: extract project picker to dedicated widget`
