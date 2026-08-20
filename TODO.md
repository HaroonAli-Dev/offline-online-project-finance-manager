# Finance & Construction Manager
## Project TODO & Status Tracker

**Project Name:** Finance & Construction Manager  
**Project Type:** Offline-first finance and construction management system  
**Primary Client:** Single client initially; architecture should remain scalable for future multi-organization use  
**Last Updated:** August 19, 2026

---

# 1. Project Vision

Replace the client's paper-register process with a simple, reliable offline-first application for construction and financial record keeping.

Core features:

- Record money received and money paid.
- Track people, roles, engineers, staff, drivers, and labour.
- Manage schemes and sites.
- Record expenses and bills.
- Track vehicles.
- Maintain project progress.
- Store photos, GPS data, and documents.
- Create reminders and view dashboards.
- Continue working without internet access.
- Synchronize with the cloud when connectivity returns.

---

# 2. Target Platforms

## Phase 1

- [ ] Android APK
- [x] Windows desktop
- [x] Flutter Web / PWA for iPhone Safari

## Phase 2 / Future

- [ ] Native iOS
- [ ] Native macOS

The initial iPhone solution is a web-based PWA, not a separate native iOS app. The app should work on Safari, be added to the home screen, and keep local data usable during temporary offline periods.

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

Supporting packages currently in use or planned:

- `file_picker`
- `csv`
- `url_launcher`
- `image_picker`, `image`, `geolocator`
- `flutter_local_notifications`
- `supabase_flutter`
- `pdf`, `printing`

---

# 4. Core Architecture

The application is built as an offline-first system with the local database as the source of truth.

```text
Flutter UI
    ↓
Riverpod
    ↓
Repositories / Services
    ↓
Drift / SQLite
    ↓
Local app data
```

When internet is available, local changes can be synced to Supabase after the local model is stable.

Core rule:

- Supabase is not required for normal offline CRUD operations.

---

# 5. Current Status

## Completed

- [x] Core Windows desktop app working
- [x] People, Sites, Schemes, Transactions, Expenses, Vehicles, Dashboard, Bills, Progress, Attachments, and Reminders implemented
- [x] Local SQLite/Drift database foundation
- [x] Offline-first local source-of-truth design
- [x] SQLite backup / restore
- [x] Cross-platform document and file attachments
- [x] Basic Flutter web / PWA support
- [x] Architecture and database audit completed
- [x] P0 and P1 critical fixes applied
- [x] Automated tests passing for the current codebase

## Remaining active work

- [ ] Final reminders/calendar enhancements
- [ ] Dashboard validation and polish
- [ ] Android validation and packaging
- [ ] Web/PWA offline validation
- [ ] Supabase auth and sync design
- [ ] Production security checks

---

# 6. Module Roadmap

## Phase 1 — Foundation

Status: Complete

- [x] Flutter project
- [x] Riverpod setup
- [x] Drift/SQLite setup
- [x] Feature-first structure
- [x] Sync queue foundation

## Phase 2 — People & Roles

Status: Complete for offline use

- [x] Add, edit, search, soft-delete people
- [x] Support normalized multi-role relationships

## Phase 3 — Sites

Status: Complete

## Phase 4 — Schemes / Projects

Status: Complete

## Phase 5 — Financial Transactions

Status: Complete

## Phase 6 — Expenses

Status: Complete

## Phase 7 — Vehicles & Drivers

Status: Complete

## Phase 8 — Bills

Status: Complete

## Phase 9 — Progress Tracking

Status: Complete

- [x] Progress repository and UI completed
- [x] Migration and repository tests added
- [x] Cross-platform validation completed for the module

## Phase 10 — Photos, GPS & Documents

Status: Complete

- [x] Attachment metadata storage and validation
- [x] GPS and image handling support
- [x] Local attachment management and filtering

## Phase 11 — Reminders & Calendar

Status: Baseline complete; enhancements pending

- [x] Reminder repository, filtering, and UI
- [ ] Calendar grouping/date selection
- [ ] Expanded relationship support for more entities
- [ ] Due-time and notification scheduling abstraction

## Phase 12 — Dashboard

Status: Complete and validated

- [x] Summary cards and quick actions
- [x] Upcoming reminders and budget utilization
- [x] Responsive dashboard layout

---

# 7. Audit Summary

The current offline application is ahead of the original staged plan and contains the core functionality required for the first client release.

Audit outcome:

- [x] Local SQLite/Drift remains the source of truth.
- [x] App architecture is suitable for future Supabase integration.
- [x] Cross-platform issues were fixed before adding cloud features.
- [x] Required security and data-integrity improvements were applied.

Open items before production readiness:

- [ ] Authentication
- [ ] Supabase sync layer
- [ ] Storage integration
- [ ] Web/PWA validation
- [ ] Android validation
- [ ] Security hardening and final deployment checks

---

# 8. Supabase & Authentication

## Status: Not yet implemented

Planned work:

- [ ] Review schema and design matching PostgreSQL tables
- [ ] Configure Supabase URL and public key
- [ ] Add Supabase Auth
- [ ] Add Row Level Security policies
- [ ] Build cloud repositories and sync queue
- [ ] Implement synchronization and conflict handling
- [ ] Add cloud storage for documents/photos

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
