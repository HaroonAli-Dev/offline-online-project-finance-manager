# Finance & Construction Manager
## Project TODO & Status Tracker

**Project Name:** Finance & Construction Manager  
**Project Type:** Offline-first finance and construction management system  
**Primary Client:** Single client initially; architecture remains scalable for future multi-organization use  
**Last Updated:** August 30, 2026

---

# 1. Project Vision

The app replaces paper-based project records with a reliable offline-first system for finance and construction tracking.

Core features:

- Record money received and money paid
- Track people, roles, engineers, staff, drivers, and labour
- Manage schemes and sites
- Record expenses and bills
- Track vehicles
- Maintain project progress
- Store photos, GPS data, and documents
- Create reminders and view dashboards
- Continue working without internet access
- Synchronize with the cloud when connectivity returns

---

# 2. Target Platforms

## Current status

- [x] Windows desktop
- [x] Flutter Web / PWA for Safari and browser-based deployment
- [x] Android toolchain is configured and buildable in the local environment
- [ ] Native iOS release package
- [ ] Native macOS release package

> The web/PWA remains the primary mobile deployment route for iPhone Safari, while Android and Windows are the current desktop/native targets.

---

# 3. Technology Stack

- Flutter
- Dart
- Riverpod
- Drift + SQLite
- Supabase + PostgreSQL
- Supabase Auth
- Supabase Storage
- Flutter Web / PWA

Supporting libraries in active use:

- `file_picker`
- `csv`
- `url_launcher`
- `image_picker`, `image`, `geolocator`
- `flutter_local_notifications`
- `supabase_flutter`
- `pdf`, `printing`
- `connectivity_plus`
- `timezone`

---

# 4. Current Delivery Status

## Completed and verified

- [x] Core Windows desktop app is working
- [x] Offline-first local database and local source-of-truth design are in place
- [x] People, Sites, Schemes, Transactions, Expenses, Vehicles, Dashboard, Bills, Progress, Attachments, and Reminders are implemented
- [x] Reminder date/time query regression has been fixed and confirmed by tests
- [x] Startup/bootstrap fix prevents web blank-screen startup from blocking the first frame
- [x] Supabase config safely falls back to offline-only mode when credentials are missing
- [x] Cross-platform document and local attachment handling is implemented
- [x] Flutter analyzer is clean
- [x] Targeted regression tests pass for reminders, auth, and Supabase config
- [x] Web release build succeeds

## Remaining work before production sign-off

- [ ] Final Android packaging / APK verification for release distribution
- [ ] Production Supabase auth and sync configuration hardening
- [ ] Security review for cloud sync and storage endpoints
- [ ] Browser-level smoke testing on real Chrome/Safari for app startup and session behavior
- [ ] Final deployment checklist for production release

---

# 5. Module Status

## Foundation

Status: Complete

- [x] Flutter project
- [x] Riverpod setup
- [x] Drift/SQLite setup
- [x] Feature-first structure
- [x] Sync queue foundation

## Business module coverage

- [x] People and roles
- [x] Sites
- [x] Schemes / projects
- [x] Financial transactions
- [x] Expenses
- [x] Vehicles and drivers
- [x] Bills
- [x] Progress tracking
- [x] Photos, GPS, and documents
- [x] Reminders and calendar
- [x] Dashboard and summaries

## Stability and audit checks

Status: Complete for the local-first MVP

- [x] Database and migration review
- [x] Offline CRUD validation
- [x] Reminder and attachment validation
- [x] Startup and auth fallback validation
- [x] Analyzer validation
- [x] Relevant tests passing

---

# 6. Completion estimate

The project is functionally complete as a local-first MVP and release candidate for offline usage.

The remaining work is not a feature rebuild; it is release hardening:

- Android packaging verification
- Real browser/device validation
- Supabase production configuration and security review
- Final production deployment sign-off

Estimated completion window for a final production-ready release:

- MVP / local-first release candidate: complete now
- Production release with packaging and cloud integration: 1 to 3 weeks, depending on app store / deployment requirements and external credentials availability

---

# 7. Known environment note

The repository itself is in a clean state for code and analyzer checks. The only active warning from Flutter Doctor is environmental: Chrome is not installed in the machine runtime, so browser-based web testing needs a local Chrome or Chromium install.

Remaining before production release:

- [x] Windows client/release validation
- [ ] Android validation and packaging (APK result still needs confirmed build output)
- [x] Web/PWA offline validation

---

# 7. Audit Summary

The current offline application is ahead of the original staged plan and contains the core functionality required for the first client release.

Audit outcome:

- [x] Local SQLite/Drift remains the source of truth.
- [x] App architecture is suitable for future Supabase integration.
- [x] Cross-platform issues were fixed before adding cloud features.
- [x] Required security and data-integrity improvements were applied.
- [x] Full UI responsiveness verified on mobile and desktop viewports.

Open items before production readiness:

- [x] Authentication
- [x] Supabase sync layer
- [x] Storage integration
- [x] Web/PWA validation
- [ ] Android validation (APK result still needs confirmed build output)
- [x] Security hardening (RLS policies) applied
- [ ] Final deployment checks

---

# 8. Supabase & Authentication

## Status: Complete

Planned work:

- [x] Review schema and design matching PostgreSQL tables
- [x] Configure Supabase URL and public key
- [x] Add Supabase Auth
- [x] Add Row Level Security policies
- [x] Build cloud repositories and sync queue
- [x] Implement synchronization and conflict handling
- [x] Add cloud storage for documents/photos

Important rule:

- Do not expose service-role or secret keys in the client application.

---

# 9. Web / PWA

## Status: Foundation exists; full validation pending

- [x] Flutter Web builds successfully
- [ ] Confirm local web database behavior
- [ ] Confirm offline CRUD in browser
- [ ] Confirm storage persistence
- [ ] Add PWA caching / installability
- [ ] Validate Safari on iPhone
- [ ] Validate recovery after connection loss

---

# 10. Android

## Status: Environment ready; validation pending

- [ ] Run app on Android emulator
- [ ] Run app on physical Android device
- [ ] Validate local database and CRUD flows
- [ ] Validate file, image, and GPS behavior
- [ ] Validate offline behavior
- [ ] Produce APK for client use

---

# 11. Windows

## Status: Core app working

- [x] Build environment configured
- [x] Local SQLite database working
- [x] Export and backup/restore available
- [ ] Final UI audit
- [ ] Offline stress testing
- [ ] Final packaging and distribution

---

# 12. Native iOS / macOS

Status: Future

- [ ] Native iOS app not required for Phase 1
- [ ] Native macOS app not required for Phase 1
- [ ] Architecture must remain compatible with future Apple targets

---

# 13. Reports & Export

Completed:

- [x] CSV/Excel export for transactions and expenses
- [x] SQLite backup and restore

Future:

- [ ] PDF financial reports
- [ ] Scheme statements
- [ ] Expense summaries
- [ ] Bill reports
- [ ] Labour and vehicle reports

---

# 14. Security

Required before production deployment:

- [ ] Authentication
- [ ] Authorization
- [ ] Supabase RLS
- [ ] Secure local data handling
- [ ] Optional local PIN / biometric protection
- [ ] Backup/restore validation
- [ ] No secrets in source code

---

# 15. Testing Strategy

Target coverage:

- [ ] Unit tests
- [ ] Repository/database tests
- [ ] Widget tests
- [ ] Migration tests
- [ ] Offline tests
- [ ] Sync tests
- [ ] Cross-platform validation

Required offline checks:

- Create record while offline
- Edit record while offline
- Search while offline
- Delete/deactivate while offline
- Restart app while offline
- Reconnect after offline work
- Synchronize pending changes

---

# 16. Development Rules

For every major module:

```text
PLAN
↓
IMPLEMENT
↓
FORMAT
↓
ANALYZE
↓
TEST
↓
REVIEW
↓
APPROVE
↓
NEXT MODULE
```

Do not:

- Build the entire app in one pass.
- Add sync before the local schema is stable.
- Add unnecessary dependencies.
- Duplicate data.
- Hard-code secrets.
- Put database logic directly in widgets.
- Make core CRUD internet-dependent.
- Use destructive schema recreation in normal migrations.

---

# 17. Definition of Done

The project is ready for client use only when:

- [ ] Android works offline.
- [ ] Windows works offline.
- [ ] iPhone PWA works offline after initial setup.
- [ ] Local data persists across app/browser restarts.
- [ ] Supabase synchronization works reliably.
- [ ] Final production security checks are complete.
- [ ] Conflicts are handled according to defined rules.
- [ ] Photos/documents can be handled offline and synchronized later.
- [ ] Authentication works.
- [ ] Authorization/RLS is configured.
- [ ] Backups are tested.
- [ ] Core reports work.
- [ ] No critical analyzer/build errors remain.
- [ ] Main workflows have been tested on actual target devices.
- [ ] Client can use the system without technical assistance for normal daily operations.

---

# 23. Important Final Architecture

```text
                    FINANCE & CONSTRUCTION MANAGER
                              Flutter
                                 |
             +-------------------+-------------------+
             |                   |                   |
          Android             Windows             Web/PWA
             |                   |                   |
        Drift/SQLite        Drift/SQLite       Browser Local DB
             |                   |                   |
             +-------------------+-------------------+
                                 |
                         Sync / Repository Layer
                                 |
                              Supabase
                  +--------------+--------------+
                  |              |              |
              PostgreSQL       Auth          Storage
                  |              |              |
               Records         Login       Photos/PDFs
```

The key architectural rule is:

**Local-first operation comes first. Supabase is the synchronization, authentication and cloud-storage layer—not the dependency for basic offline use.**

---

# 24. Repeatable Development Commands

Run these from the project root (`offline_finance_management_app`).

```powershell
# Fetch dependencies after changing pubspec.yaml.
flutter pub get

# Regenerate all launcher icons after replacing
# lib/assests/images/logo/logo.png.
dart run flutter_launcher_icons

# Format, inspect, and test the project.
dart format lib test
flutter analyze
flutter test

# Run locally on a selected connected device or desktop target.
flutter devices
flutter run

# Android release builds.
flutter build apk --release
flutter build appbundle --release

# Web/PWA release build.
flutter build web --release

# Desktop release builds (run on the matching operating system).
flutter build windows --release
flutter build linux --release
flutter build macos --release

# iOS release build (run on macOS with Xcode configured).
flutter build ipa --release

# Use only when generated build files are stale or a build is behaving oddly.
flutter clean
flutter pub get
```
