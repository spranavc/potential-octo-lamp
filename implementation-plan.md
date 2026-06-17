# Implementation Plan: Bouldering Progress Tracking App

## Context

Greenfield Flutter app for iOS. User develops on Windows 11, tests on Chrome + Android emulator during development, periodic Codemagic iOS builds. The app helps climbers log sessions, track grades, identify strengths/weaknesses, and visualize progress.

## Phases Overview

| Phase | What | Testable on Windows? |
|---|---|---|
| 0 | Project scaffold + CI | ✅ `flutter analyze`, `flutter test` |
| 1 | Database schema + repos | ✅ Unit tests |
| 2 | Session logging feature | ✅ Chrome + Android emulator |
| 3 | Gym management | ✅ Chrome + Android emulator |
| 4 | Progress analytics | ✅ Chrome + Android emulator |
| 5 | Performance features | ✅ Chrome + Android emulator |
| 6 | Project management | ✅ Chrome + Android emulator |
| 7 | Settings + polish | ✅ Chrome + Android emulator |

Each phase ships a complete, testable increment. Later phases build on earlier ones.

---

## Phase 0: Project Scaffold

### Goal
Working Flutter project that passes CI (analyze + test). Empty app shell with routing skeleton, theme, and dependency injection.

### Files to create

```
pubspec.yaml                          # Dependencies
analysis_options.yaml                 # Linting rules
lib/main.dart                         # Entry point, ProviderScope
lib/app.dart                          # MaterialApp.router with GoRouter
lib/core/theme/app_theme.dart         # ThemeData (light + dark scaffolds)
lib/core/routing/app_router.dart      # GoRouter config with stub routes
lib/core/extensions/                  # (empty, placeholder)
lib/shared/widgets/                   # (empty, placeholder)
lib/shared/utils/                     # (empty, placeholder)
test/app_test.dart                    # Smoke test: app renders
```

### Key dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  go_router: ^14.8.1
  drift: ^2.33.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  riverpod_generator: ^2.6.1
  build_runner: ^2.4.0
  drift_dev: ^2.32.1
  custom_lint: ^0.7.0
  riverpod_lint: ^2.6.1
```

### Verification
- `flutter analyze` passes (0 issues)
- `flutter test` passes (app smoke test)
- `flutter run -d chrome` shows empty scaffold with bottom nav

---

## Phase 1: Database Schema + Repositories

### Goal
Full Drift schema covering all MVP entities. Repository layer with CRUD operations. All tested via unit tests (no UI yet).

### Drift Schema

```
gyms
  id: int (PK, autoincrement)
  name: String
  created_at: DateTime

walls
  id: int (PK, autoincrement)
  gym_id: int (FK → gyms.id)
  name: String
  created_at: DateTime

gym_colors
  id: int (PK, autoincrement)
  gym_id: int (FK → gyms.id)
  color_name: String       # e.g. "red", "blue"
  color_hex: String         # e.g. "#FF0000"
  grade_system: String      # "V-scale" or "Font"
  grade_value: String       # e.g. "V4", "6B+"
  created_at: DateTime

sessions
  id: int (PK, autoincrement)
  gym_id: int (FK → gyms.id)
  wall_id: int? (FK → walls.id, nullable)
  started_at: DateTime
  ended_at: DateTime?
  notes: String?
  created_at: DateTime

climbs
  id: int (PK, autoincrement)
  session_id: int (FK → sessions.id)
  grade_system: String      # "V-scale" or "Font"
  grade_value: String       # e.g. "V5", "7A"
  sent: bool                # true = send, false = fail
  attempts: int             # number of attempts
  rpe: double?              # Rate of Perceived Exertion (1-10), nullable
  notes: String?
  logged_at: DateTime
  created_at: DateTime

tags
  id: int (PK, autoincrement)
  name: String (unique)     # "crimpy", "dynamic", "slopey", "overhang", "slab"
  created_at: DateTime

climb_tags
  climb_id: int (FK → climbs.id)
  tag_id: int (FK → tags.id)
  PRIMARY KEY (climb_id, tag_id)

projects
  id: int (PK, autoincrement)
  gym_id: int (FK → gyms.id)
  name: String
  grade_system: String
  grade_value: String
  description: String?
  status: String            # "active", "completed", "abandoned"
  started_at: DateTime?
  completed_at: DateTime?
  created_at: DateTime

project_climbs
  project_id: int (FK → projects.id)
  climb_id: int (FK → climbs.id)
  PRIMARY KEY (project_id, climb_id)
```

### Files to create

```
lib/data/database/database.dart         # @DriftDatabase definition
lib/data/database/tables.dart            # All table definitions
lib/data/database/daos/                  # Per-entity DAOs
lib/data/database/daos/gyms_dao.dart
lib/data/database/daos/sessions_dao.dart
lib/data/database/daos/climbs_dao.dart
lib/data/database/daos/tags_dao.dart
lib/data/database/daos/projects_dao.dart
lib/data/repositories/gym_repository.dart
lib/data/repositories/session_repository.dart
lib/data/repositories/climb_repository.dart
lib/data/repositories/tag_repository.dart
lib/data/repositories/project_repository.dart
lib/data/providers/database_provider.dart    # Provider<AppDatabase>
lib/data/providers/repository_providers.dart # Providers for each repository
test/data/database/tables_test.dart
test/data/repositories/session_repository_test.dart
test/data/repositories/climb_repository_test.dart
```

### Patterns

- Each DAO returns `Future<List<T>>` for reads, `Future<void>` for writes
- Repositories wrap DAOs, add validation
- Providers: `databaseProvider` → `sessionRepositoryProvider` (depends on DB) → feature providers (depend on repos)
- Tests use in-memory SQLite (Drift's `NativeDatabase.memory()`)

### Seed data

- 5 default tags: "crimpy", "dynamic", "slopey", "overhang", "slab" — inserted at DB creation via migration callback

### Verification
- All repository unit tests pass (CRUD + edge cases)
- `dart run build_runner build` generates Drift code without errors

---

## Phase 2: Session Logging

### Goal
User can start a session, log climbs with swipe gestures, see session summary.

### Screens
```
/session-log              → SessionLogHome (list of past sessions + "Start New" button)
/session/:id              → ActiveSessionScreen (the logging screen)
/session/:id/summary      → SessionSummaryScreen (after ending session)
```

### Key widgets
- `SwipeCard` — the core interaction. Card shows current climb grade/tags. Swipe left → fail, right → send
- `GradePicker` — bottom sheet to pick V-scale or Font grade
- `TagChips` — selectable chip row for style tags
- `AttemptsCounter` — tap +/- to adjust attempts
- `RpeSlider` — 1-10 slider for fatigue tracking

### Key providers
- `activeSessionProvider` (StateNotifier) — holds current session state: list of logged climbs, start time, selected gym/wall
- `climbLogProvider` — logged climb list for history views

### Files to create

```
lib/features/session_log/
  screens/
    session_log_home.dart
    active_session_screen.dart
    session_summary_screen.dart
  widgets/
    swipe_card.dart
    grade_picker.dart
    tag_chips.dart
    attempts_counter.dart
    rpe_slider.dart
  providers/
    active_session_provider.dart
    session_list_provider.dart
lib/domain/services/session_service.dart   # Business logic: start/end session, log climb
test/features/session_log/
  active_session_provider_test.dart
  session_service_test.dart
```

### UX flow
1. Tap "Start New Session" → pick gym + wall
2. ActiveSessionScreen shows a swipeable card stack
3. Each card: grade at top, tags as chips, attempts counter, RPE slider
4. Swipe left → logs as fail, right → logs as send
5. Next card appears immediately (the 2-3 second target)
6. Tap "End Session" → SessionSummaryScreen (pyramid preview, send rate, duration)

### Verification
- Provider tests: logging a climb updates active session state correctly
- Service tests: session start/end timestamps, climb count
- Widget tests: swipe card renders, grade picker opens/closes
- Manual: `flutter run -d chrome` — tap through a full session flow

---

## Phase 3: Gym Management

### Goal
User can create gyms, add walls, configure color-to-grade mappings.

### Screens
```
/gyms                     → GymsListScreen
/gyms/:id                 → GymDetailScreen (walls, colors, recent sessions)
/gyms/:id/colors          → GymColorsScreen (color decoder configuration)
```

### Key providers
- `gymListProvider` (FutureProvider) — list of all gyms
- `gymDetailProvider(gymId)` (FutureProvider.family) — single gym + walls + colors
- `gymColorsProvider(gymId)` — color-to-grade mappings

### Files to create

```
lib/features/gyms/
  screens/
    gyms_list_screen.dart
    gym_detail_screen.dart
    gym_colors_screen.dart
  widgets/
    gym_card.dart
    wall_list_tile.dart
    color_grade_mapping.dart
  providers/
    gym_providers.dart
```

### Verification
- CRUD gym, wall, color mapping
- Widget tests: gym list renders, gym detail shows walls and colors

---

## Phase 4: Progress Analytics

### Goal
Grade pyramid, activity heatmap, hardest sends chart, send rate by grade.

### Screens
```
/analytics                → AnalyticsDashboard (scrollable with sections)
  Sections:
    - Grade pyramid (bar chart)
    - Activity heatmap (GitHub-style)
    - Hardest sends over time (line chart)
    - Send rate by grade (horizontal bar chart)
```

### Chart library: `fl_chart`

### Key providers
- `gradePyramidProvider` — groups climbs by grade, counts sends/fails
- `activityHeatmapProvider` — climbs per day over last N months
- `hardestSendsProvider` — max grade sent per week over time
- `sendRateProvider` — send/(send+fail) per grade

### Domain services
```
lib/domain/services/analytics_service.dart
  - gradeDistribution(sessions)
  - activityHeatmap(sessions, range)
  - hardestSendsOverTime(sessions)
  - sendRateByGrade(sessions)
  - styleBiasHeatmap(sessions)         # USP feature
```

### Files to create

```
lib/features/analytics/
  screens/
    analytics_dashboard.dart
  widgets/
    grade_pyramid_chart.dart
    activity_heatmap.dart
    hardest_sends_chart.dart
    send_rate_chart.dart
    style_bias_heatmap.dart
  providers/
    analytics_providers.dart
lib/domain/services/analytics_service.dart
test/domain/services/analytics_service_test.dart
test/features/analytics/
  analytics_providers_test.dart
```

### Verification
- Service unit tests: grade pyramid calculation correct, send rate math correct, heatmap date bucketing correct
- Widget tests: charts render with mock data
- Manual: log a session → see analytics update

---

## Phase 5: Performance Features

### Goal
Session performance curve, peak performance window, fatigue tracking, weakness prescription.

### This is the USP-heavy phase.

### Key providers
- `sessionPerformanceCurveProvider(sessionId)` — grade success over time within session
- `peakPerformanceWindowProvider` — time-of-day analysis across sessions
- `fatigueTrackerProvider` — RPE trend over session + across sessions
- `weaknessPrescriptionProvider` — identifies under-attempted styles at grade

### Domain services
```
lib/domain/services/performance_service.dart
  - sessionPerformanceCurve(session)    # grade vs. climb order within session
  - peakWindow(sessions)                # best send rate by time of day
  - fatigueTrend(sessions)              # RPE vs. session duration
  - weaknessPrescription(sessions)      # styles where send rate is low relative to grade
```

### Files to create

```
lib/features/analytics/widgets/
  session_performance_curve.dart
  peak_window_chart.dart
  fatigue_chart.dart
  weakness_prescription_card.dart
test/domain/services/performance_service_test.dart
```

### Verification
- Service tests: performance curve slope calculation, peak window clustering, weakness detection logic
- Manual: view performance tab after logging 3+ sessions

---

## Phase 6: Project Management

### Goal
User can create projects (target climbs), attach logged climbs, track progress.

### Screens
```
/projects                 → ProjectsListScreen
/projects/:id             → ProjectDetailScreen (notes, attached climbs, progress)
```

### Key providers
- `projectListProvider` — all projects
- `projectDetailProvider(projectId)` — project + attached climbs

### Files to create

```
lib/features/projects/
  screens/
    projects_list_screen.dart
    project_detail_screen.dart
  widgets/
    project_card.dart
    project_progress_bar.dart
    climb_attachment_list.dart
  providers/
    project_providers.dart
```

### Verification
- Create project, attach climbs from existing sessions, mark complete
- Widget tests: project list, project detail with attached climbs

---

## Phase 7: Settings + Polish

### Goal
App settings, data export, about page, visual polish.

### Screens
```
/settings                 → SettingsScreen
  - Data export (JSON/CSV)
  - Delete all data
  - About
```

### Files to create

```
lib/features/settings/
  screens/
    settings_screen.dart
  widgets/
    export_button.dart
lib/domain/services/export_service.dart
```

### Verification
- Export produces valid JSON
- Delete all data clears the database
- Test that export → delete → re-import (future) round-trips

---

## Key Design Decisions

1. **Why sessions before gyms?** Phase 1 creates the gym schema, but Phase 2 (session logging) is the core UX — a "default gym" can be auto-created so the logging flow works immediately. Phase 3 adds full gym management.

2. **Why Drift DAOs + repositories?** DAOs are raw query methods. Repositories add validation and business-rules context. This keeps the database layer swappable and testable.

3. **Why fl_chart?** Most mature Flutter chart library. Supports bar, line, scatter, and heatmap-like visualizations. All analytics features can be built with it.

4. **Testing on Windows**: Every phase produces UI testable in Chrome. Gesture testing (swipe-to-log) works in Chrome but should be validated on Android emulator for touch feel.

5. **No authentication, no backend.** MVP is fully local. Realm/backend can be added later without changing the repository interfaces (swap implementations).

---

## Testing Strategy

| Layer | Tool | Per phase |
|---|---|---|
| Database | `NativeDatabase.memory()` in tests | Phase 1+ |
| Repositories | Unit tests with in-memory DB | Phase 1+ |
| Domain services | Pure Dart unit tests | Phase 1+ |
| Providers | Provider override in tests | Phase 2+ |
| Widgets | `WidgetTester` in Flutter test | Phase 2+ |
| Integration | `flutter run -d chrome` manual smoke | Every phase |
| iOS device | Codemagic ad-hoc build | ~monthly |
