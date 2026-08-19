# Finance & Construction Manager
## Project TODO & Status Tracker

**Project Name:** Finance & Construction Manager  
**Project Type:** Offline-First Finance & Construction Management System  
**Primary Client:** Single client initially; architecture should remain scalable for future multi-organization use  
**Last Updated:** August 19, 2026 (local modules through Reminders and Dashboard are implemented; package resolution for planned integrations is pending registry connectivity)

---

# 1. Project Vision

Replace the client's paper-register-based record keeping with a secure, simple, offline-first application for construction/project and financial records.

The application must allow the client to:

- Record money received and money paid.
- Track people, roles, engineers, staff, drivers and labour.
- Manage construction schemes/projects and sites.
- Record expenses.
- Track vehicles.
- Manage bills and project progress.
- Store photos, GPS coordinates and documents.
- Create reminders.
- View dashboards and reports.
- Continue working when internet is unavailable.
- Synchronize with the cloud when internet becomes available.

The client currently uses registers and pen, so the application must prioritize simplicity, reliability and easy data entry.

---

# 2. Target Platforms

## Phase 1

- [ ] Android — native Flutter APK
- [x] Windows Desktop — native Flutter application
- [x] Flutter Web — hosted PWA for iPhone/Safari

## Phase 2 / Future

- [ ] Native iOS application
- [ ] Native macOS application

### Important platform strategy

The initial iPhone solution is **Flutter Web + PWA**, not a separate native iOS application.

The client will:

1. Open the hosted web application in Safari.
2. Log in.
3. Add the PWA to the iPhone Home Screen.
4. Use the application from the Home Screen.
5. Continue using the application during temporary internet outages when local web storage/cache is available.
6. Synchronize with Supabase when internet returns.

Native iOS can be added later without redesigning the core application architecture.

---

# 3. Technology Stack

## Application

- Flutter
- Dart
- VS Code for development

## State Management

- Riverpod

## Local Database

- Drift
- SQLite

## Cloud Backend

- Supabase
- PostgreSQL

## Authentication

- Supabase Auth

## Cloud File Storage

- Supabase Storage

## Web

- Flutter Web
- PWA/offline web capabilities

## Supporting Packages

Installed and used:

- `file_picker` — cross-platform file selection for attachments.
- `csv` — transaction and expense export.
- `url_launcher` — safely opens locally stored attachments.

Declared for upcoming integration work; not yet resolved because `pub.dev` was unreachable during the latest `flutter pub get` attempt:

- `image_picker`, `image`, and `geolocator` — camera/gallery and live location capture.
- `flutter_local_notifications` — scheduled local reminder notifications.
- `supabase_flutter` — authentication, cloud storage, and synchronization.
- `pdf` and `printing` — printable reports.

`connectivity_plus` and a maps package remain unnecessary until their features are designed.

---

# 4. Core Architecture

The application is **Offline-First**.

Normal application operations must use the local database first.

```text
Flutter UI
    ↓
Riverpod
    ↓
Repositories / Services
    ↓
Drift / SQLite
    ↓
Local application data
```

When internet is available:

```text
Local Changes
    ↓
Sync Queue
    ↓
Supabase
    ↓
PostgreSQL / Storage
    ↓
Other authorized devices
```

### Core principle

**Supabase must not be required for normal offline CRUD operations.**

The application should continue functioning when:

- Internet is unavailable.
- Internet is slow.
- Internet disconnects temporarily.
- The connection repeatedly comes and goes.

---

# 5. Data Synchronization Strategy

Synchronization will be implemented after the local database and domain model are stable.

The sync system should eventually support:

- Create synchronization
- Update synchronization
- Delete synchronization
- Retry after failed sync
- Sync queue
- Sync status
- Last synced timestamp
- Conflict handling
- Remote changes downloaded to local database
- Local changes uploaded to Supabase

Records that participate in synchronization should use appropriate metadata such as:

- `id`
- `createdAt`
- `updatedAt`
- `deletedAt` when soft deletion is required
- `syncStatus`
- `lastSyncedAt`
- Remote/server identifier if needed

Do not implement a complex sync engine before the local schema is approved and stable.

---

# 6. Current Project Status

## Development Environment

- [x] Flutter SDK installed
- [x] Android Studio installed
- [x] Android SDK installed
- [x] Android emulator installed
- [x] Flutter plugin installed in Android Studio
- [x] Flutter extension installed in VS Code
- [x] Visual Studio Community installed
- [x] Desktop development with C++ configured
- [x] Windows Flutter build environment configured
- [x] Git installed
- [x] Flutter Web successfully tested with Microsoft Edge

## Project Foundation

- [x] Removed Flutter default counter application
- [x] Added professional starting screen
- [x] Added Riverpod foundation
- [x] Added Drift + SQLite local database foundation
- [x] Added synchronization queue foundation for future Supabase sync
- [x] Added Web database foundation
- [x] Added feature-first project structure
- [x] Added basic project documentation
- [x] `flutter analyze` successfully completed
- [x] Core Windows build pipeline successfully configured

---

# 7. Important Current State Correction

The current offline Windows application contains more functionality than the original staged plan.

Implemented so far:

- People ✅
- Sites ✅
- Schemes ✅
- Financial Transactions ✅
- Expenses ✅
- Vehicles ✅
- Dashboard ✅
- Data export ✅
- SQLite backup/restore ✅
- Cross-platform receipt/file attachments ✅

### Audit status: ✅ COMPLETED

The architecture and database audit has been completed. All approved P0 and P1 fixes have been applied.

### Pre-Supabase audit summary

**Audit completed:** 2026-08-17  
**Scope:** architecture, database integrity, offline-first local source-of-truth, security hardening, cross-platform compatibility, performance, error handling, and future Supabase readiness.

**Issues found:**
- Unsafe local file launch paths could allow traversal or malformed file references in shared file-opening code.
- Minor analyzer warnings remained from a single const usage and a few mutable test locals.
- The project is structurally sound for Supabase readiness, but no auth or Supabase integration has been added.

**Issues fixed:**
- Hardened `FileLauncherService` with validation that blocks empty, traversal, file://, and malformed references before launching files.
- Kept the existing local SQLite/Drift design as the source of truth without introducing Supabase dependencies.
- Cleaned up the final analyzer warnings and fixed test variable usage while preserving all current behavior.

**Remaining technical debt before Supabase Auth / Phase 13:**
- No Supabase Auth, Postgres sync layer, or storage integration is present yet and remains intentionally out of scope for this audit gate.
- Future sync contracts, conflict handling, and remote schema alignment still need to be designed once Supabase is introduced.
- The app should continue to treat offline local data as authoritative until online synchronization is implemented and validated.

### Current priority

**Resume feature development: Bills module, Progress tracking, Photos/GPS/Documents, and Reminders.**

---

# 8. Architecture & Database Audit

## Status: ✅ COMPLETED

### Audit the existing codebase

- [x] Review Drift database schema.
- [x] Review all current tables.
- [x] Review relationships and foreign keys.
- [x] Review People/Roles design.
- [x] Verify roles are normalized and extensible.
- [x] Review Sites schema.
- [x] Review Schemes schema.
- [x] Review Transactions schema.
- [x] Review Expenses schema.
- [x] Review Vehicles/Drivers schema.
- [x] Review Dashboard data calculations.
- [x] Review IDs and relationships.
- [x] Review timestamps.
- [x] Review soft deletion strategy.
- [x] Review synchronization metadata.
- [x] Identify Windows-only code.
- [x] Identify Web-incompatible code.
- [x] Identify Android-incompatible code.
- [x] Check that local data model can map cleanly to PostgreSQL.
- [x] Identify redundant/duplicated fields.
- [x] Identify unnecessary dependencies.
- [x] Identify any architecture changes required before Supabase integration.

### Approved fixes applied

**P0 (Critical):**
- [x] P0-1: Removed Windows-only `explorer.exe` call. Replaced with cross-platform `FileLauncherService` using `url_launcher`.
- [x] P0-2: Refactored `ExportService` for cross-platform support (Windows/Android/Web).
- [x] P0-3: Fixed database backup/export path architecture for cross-platform compatibility.

**P1 (Important):**
- [x] P1-4: Converted monetary storage from `double`/REAL to `int` (paisa). Schema migration v8→v9.
- [x] P1-5: Normalized `PersonRoles` junction table — composite PK `(person_id, role_code)`, removed `id` and `deleted_at`.
- [x] P1-6: UTC timestamp standardization across all repositories.
- [x] P1-7: Transactional `SyncOutbox` enqueueing in all repositories.

### Verification

- [x] All 25 tests across 13 test files pass clean.
- [x] Layout overflow fixes applied to all filter side panels.

---

# 9. Module Roadmap

The following order is the intended development order.

## Phase 1 — Foundation

### Status: Mostly complete

- [x] Flutter project
- [x] Riverpod
- [x] Drift/SQLite
- [x] Local database foundation
- [x] Feature-first structure
- [x] Sync queue foundation
- [x] Responsive application shell

---

## Phase 2 — People & Roles

### Status: ✅ Implemented & Audited

People should support:

- [x] Add person
- [x] Edit person
- [x] Search people
- [x] Activate/deactivate
- [x] Soft delete

Roles should support future role values without hard-coded application changes.

Expected roles include:

- SDO
- Engineer
- XEN
- PEON
- DO
- Accountant
- Clerk
- Driver
- Labour
- Security
- Staff
- Other

A person may require multiple roles, so the data model should support a normalized person-role relationship where appropriate.

---

## Phase 3 — Sites

### Status: ✅ Implemented & Audited

Expected fields/features:

- Site
- Road name
- Road segment / KM information
- Coordinates
- Status
- Notes
- Related engineer
- Related scheme
- Site progress

Statuses may include:

- Planned
- Active
- On Hold
- Completed

---

## Phase 4 — Schemes / Projects

### Status: ✅ Implemented & Audited

Expected fields/features:

- Scheme ID
- Scheme name
- Site
- Budget/price
- Engineer
- Start date
- End date
- Status
- Description
- Progress percentage
- Related bills
- Related expenses
- Related transactions
- Related documents/photos

---

## Phase 5 — Financial Transactions

### Status: ✅ Implemented & Audited

Support:

- Money Received
- Money Paid

Expected fields:

- Date
- Type
- Person/Bank
- Amount
- Purpose
- Payment method
- Reference number
- Scheme
- Site
- Remarks

Payment methods may include:

- Cash
- Bank
- Cheque

The system must calculate:

- Total received
- Total paid
- Net balance

---

## Phase 6 — Expenses

### Status: ✅ Implemented & Audited

Expense categories include:

- Labour
- Vehicle
- Office
- Security
- Dinner
- Material
- Personal
- Miscellaneous

Expenses should support appropriate links to:

- Scheme
- Site
- Person/vendor
- Vehicle

and fields such as:

- Date
- Amount
- Purpose
- Notes
- Attachment

---

## Phase 7 — Vehicles & Drivers

### Status: ✅ Implemented & Audited

Support:

- Vehicle registry
- Driver assignment
- Site assignment
- Fuel records
- Maintenance records
- Trip records
- Daily vehicle expenditure

Vehicle examples:

- Truck
- Dumper
- Excavator
- Tractor
- Other

---

## Phase 8 — Bills

### Status: ✅ Implemented & Audited

Support:

- Initial Bill
- First Bill
- Second Bill
- Third Bill
- Fourth Bill
- Final Bill

Each bill should support:

- Scheme
- Date
- Amount
- Status
- Documents
- Remarks

---

## Phase 9 — Progress Tracking

### Status: ✅ Implemented & Audited

- [x] Database table `progress_updates` (schema version 11)
- [x] Migration v10 → v11 (non-destructive, existing data preserved)
- [x] `ProgressRepository` — create, update, soft-delete, watch, search, filter
- [x] SyncOutbox integration (entityType/entityId pattern, transactional)
- [x] Parent scheme status/percentage auto-updated on every progress mutation
- [x] Riverpod providers: list, filters, search, scheme-scoped history
- [x] `ProgressPage` — list, search, scheme filter, status filter, add/edit/delete
- [x] `ProgressFormDialog` — scheme, status, percentage, date, incomplete reason, result, remarks
- [x] `SchemeProgressPage` — per-scheme history with summary header
- [x] Scheme integration — "View Progress" in scheme card three-dot menu
- [x] Dashboard integration — Completed/Active/Incomplete scheme counts already present
- [x] Navigation — Progress added to rail and bottom bar
- [x] 25 repository tests passing
- [x] Migration test (v10 → v11) added to app_database_test.dart
- [x] `flutter analyze` — No issues found
- [x] `flutter test` — 70/70 tests passing
- [x] Cross-platform: no dart:io, no platform-specific code

Statuses:

- Initial
- Working
- In Progress
- Completed
- Incomplete

Incomplete work supports:

- Incomplete reason (required when status = incomplete)
- Result
- Remarks
- Date

Limitations:

- Windows debug build was validated after this module was completed.
- Android/Web compilation not validated on device
- No dedicated progress widget tests (repository + integration tests cover the logic)

---

## Phase 10 — Photos, GPS & Documents

### Status: ✅ Implemented & Audited

- [x] Database table `attachments` (schema version 12)
- [x] Migration v11 → v12 (non-destructive, all existing data preserved)
- [x] `AttachmentsRepository` — create, update, soft-delete, watchByEntity, watchAll with category filter
- [x] SyncOutbox integration (entityType/entityId pattern, transactional)
- [x] Polymorphic entity linking — scheme, site, bill, expense, progress_update
- [x] GPS coordinates (latitude/longitude) stored per attachment
- [x] File metadata only — no binary blobs in database
- [x] Cross-platform file picker via existing `file_picker` package
- [x] `AttachmentPickerService` — picks any file or image, detects MIME from extension
- [x] `AttachmentsPanel` — reusable widget embedded in any entity detail page
- [x] `SchemeAttachmentsPage` — dedicated page for scheme attachments
- [x] Scheme card "View Attachments" menu item added
- [x] Riverpod providers: `entityAttachmentsProvider` (family), `allAttachmentsProvider` (family)
- [x] 18 repository tests passing
- [x] Migration test (v11 → v12) added to app_database_test.dart
- [x] `flutter analyze` — No issues found
- [x] `flutter test` — 89/89 tests passing
- [x] Cross-platform: no dart:io in shared code, kIsWeb guard in picker service

Categories supported:
- Photo
- Document
- Receipt
- Other File

Limitations:
- GPS coordinates are manually entered; live capture is not implemented. `geolocator` is declared but awaits package resolution.
- On Web, filePath is null (file bytes are in browser memory only; no persistent local path)
- Windows debug build was validated after this module was completed.
- Android/Web compilation not validated on device
- No dedicated attachment widget tests (repository tests cover all business logic)

---

## Phase 11 — Reminders & Calendar

### Status: ✅ Implemented & Audited

- [x] Database table `reminders` (schema version 13)
- [x] Migration v12 → v13 (non-destructive, all existing data preserved)
- [x] `RemindersRepository` — create, update, markDone, soft-delete, watchReminders with search/priority/done/scheme filters
- [x] SyncOutbox integration (entityType/entityId pattern, transactional)
- [x] Optional links to Scheme and Site (joined names in query)
- [x] Priority: low, medium, high
- [x] Completion tracking: isDone + doneAt
- [x] isOverdue helper on domain model
- [x] Ordering: pending before done, then by due_at ASC NULLS LAST
- [x] Riverpod providers: search, priority filter, done filter, scheme filter
- [x] `RemindersPage` — list, search, priority filter, done/pending filter, add/edit/delete, mark-done checkbox
- [x] `_ReminderFormDialog` — title, description, priority, due date picker, linked scheme/site, remarks
- [x] Navigation — Reminders added to rail and bottom bar
- [x] 22 repository tests passing
- [x] Migration test (v12 → v13) added to app_database_test.dart
- [x] `flutter analyze` — No issues found
- [x] `flutter test` — 112/112 tests passing
- [x] Cross-platform: no dart:io, no platform-specific code

Limitations:
- Local push notifications are not yet implemented. `flutter_local_notifications` is declared but awaits package resolution.
- Windows debug build was validated after this module was completed.
- Android/Web compilation not validated on device

---

## Phase 12 — Dashboard

### Status: ✅ Implemented & Validated

Dashboard now shows:

- Total received (unfiltered, all transactions)
- Total paid (unfiltered)
- Net balance
- Total expenses (unfiltered)
- Total billed across all bills
- Bills paid total
- Active schemes count
- Completed schemes count
- Incomplete schemes count
- Active sites / total sites
- Active schemes / total schemes
- Workforce count
- Upcoming reminders (overdue + due within 7 days, max 5, with mark-done checkbox)
- Scheme budget utilization (top 5 schemes with progress bar)
- Quick Actions: Add Transaction, Add Expense, Add Person, Add Site, Add Scheme

Key fixes applied during validation:
- `dashboardTransactionSummaryProvider` and `dashboardTotalExpensesProvider` added — unfiltered, not affected by page-level search/filter state
- `dashboardBillsSummaryProvider` added — total billed / total paid across all bills
- `dashboardUpcomingRemindersProvider` added — pending reminders due within 7 days or overdue
- Summary cards split into two responsive rows (4 + 5) to avoid cramped wide layout
- `_SectionTitle` extracted as reusable widget
- `_ResponsiveCardGrid` extracted to handle 2-column grid on narrow / row on wide

---

# 10. Authentication

## Status: Not yet implemented

Use:

- Supabase Auth

Potential features:

- Login
- Logout
- Session persistence
- Password reset
- User profile
- Future role-based access

Do not expose Supabase secret/service-role credentials in the Flutter application.

Authentication should be introduced after the local application architecture is stable.

---

# 11. Supabase Integration

## Status: Not yet implemented

### Supabase project

- [x] Supabase project created
- [x] Project region selected: `ap-south-1` (Mumbai)

### Next Supabase tasks

- [ ] Review local Drift schema first.
- [ ] Design matching PostgreSQL schema.
- [ ] Create PostgreSQL tables.
- [ ] Create indexes.
- [ ] Create foreign keys.
- [ ] Create Row Level Security policies.
- [~] Resolve `supabase_flutter` (declared in `pubspec.yaml`; download blocked by `pub.dev` connectivity).
- [ ] Configure Supabase URL.
- [ ] Configure public/publishable key.
- [ ] Never place service-role/secret keys in Flutter client.
- [ ] Add Supabase Auth.
- [ ] Add cloud data repositories/services.
- [ ] Implement synchronization.

---

# 12. Supabase Storage

## Status: Not yet implemented

Use Supabase Storage for:

- Site photos
- Scheme photos
- Receipts
- Bills
- PDFs
- Contracts
- Drawings
- Other documents

The local database should store metadata and references, not large binary files.

Offline files should remain locally available and enter a future upload queue when internet returns.

---

# 13. Web / PWA

## Status: Foundation exists; full web deployment not complete

Target:

**Flutter Web + PWA**

Requirements:

- [x] Confirm Flutter Web builds successfully.
- [ ] Confirm local web database behavior.
- [ ] Confirm offline CRUD in browser.
- [ ] Confirm browser storage persistence.
- [ ] Add PWA caching/installability.
- [ ] Test Safari on iPhone.
- [ ] Test loss and restoration of internet.
- [ ] Ensure local data remains usable during intermittent connectivity.
- [ ] Deploy privately.
- [ ] Protect application with authentication.

The web application should not expose client data publicly.

---

# 14. Android

## Status: Environment configured; application validation pending

### 2. Bills Module (Completed)
**Goal:** Track construction billing stages linked to Schemes.

*   [x] Database table `bills`.
*   [x] Add fields: `scheme_id` (FK), `bill_type` (initial, 1st, 2nd, etc.), `bill_number` (optional), `bill_date`, `amount`, `status`, `remarks`.
*   [x] UI: `BillsPage` (list) and `BillFormDialog` (create/edit).
*   [x] Statuses: draft, submitted, approved, paid, rejected.
*   [x] Filter bills by `scheme_id`, `status`.

- [ ] Run application on Android emulator.
- [ ] Run application on physical Android device.
- [ ] Validate local database.
- [ ] Validate CRUD.
- [ ] Validate images/files.
- [ ] Validate GPS.
- [ ] Validate notifications.
- [ ] Validate offline behavior.
- [ ] Validate sync later.
- [ ] Produce APK for client.

No Google Play Store deployment is required for the initial client.

---

# 15. Windows

## Status: Core application working

- [x] Windows build environment configured
- [x] Windows application builds
- [x] Local SQLite database
- [x] Dashboard
- [x] CRUD modules
- [x] Export
- [x] Backup/restore
- [x] File attachments

Remaining validation:

- [ ] Final responsive UI audit
- [ ] Offline stress testing
- [ ] Data backup/restore testing
- [ ] Final client packaging
- [ ] Installer/distribution method

No Microsoft Store deployment is required.

---

# 16. Native iOS / macOS

## Status: Future

Native iOS and macOS applications are not required for Phase 1.

The existing Flutter architecture must remain compatible with future native Apple targets.

For native iOS/macOS builds, access to compatible macOS/Xcode tooling will be required later.

---

# 17. Reports & Export

Existing:

- [x] Excel/CSV export for transactions and expenses
- [x] SQLite backup
- [x] SQLite restore

Future:

- [ ] PDF financial reports
- [ ] Scheme statements
- [ ] Expense summaries
- [ ] Bill reports
- [ ] Labour/wage reports
- [ ] Vehicle reports
- [ ] Printable transaction receipts

---

# 18. Security

Required before final production deployment:

- [ ] Authentication
- [ ] Strong authorization
- [ ] Supabase Row Level Security
- [ ] Secure local data handling
- [ ] Optional local PIN
- [ ] Optional biometric protection
- [ ] Secure cloud storage
- [ ] Audit logging where appropriate
- [ ] No secrets in source code
- [ ] Backup/restore validation

---

# 19. Testing Strategy

Every module should eventually have:

- [ ] Unit tests
- [ ] Repository/database tests
- [ ] Widget tests where valuable
- [ ] Migration tests
- [ ] Offline tests
- [ ] Sync tests
- [ ] Cross-platform tests

### Required offline tests

- Create record while offline
- Edit record while offline
- Search while offline
- Delete/deactivate while offline
- Restart application while offline
- Restore from backup
- Reconnect after offline work
- Synchronize pending changes

---

# 20. Development Rules

This is a real production application.

Development must happen incrementally.

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

- Generate the entire application at once.
- Add cloud synchronization before the local model is stable.
- Add unnecessary dependencies.
- Duplicate data unnecessarily.
- Hard-code secrets.
- Put direct database logic inside UI widgets.
- Put direct Supabase calls inside UI widgets.
- Make core CRUD internet-dependent.
- Use destructive schema recreation during normal migrations.
- Claim a feature is production-ready before it has been tested on its target platforms.

---

# 21. Current Immediate Roadmap

## ✅ DONE

1. [x] Stop new feature development.
2. [x] Audit existing architecture.
3. [x] Audit Drift database schema.
4. [x] Audit People/Roles normalization.
5. [x] Audit Sites/Schemes/Transactions/Expenses/Vehicles relationships.
6. [x] Audit cross-platform compatibility.
7. [x] Audit sync readiness.
8. [x] Fix approved P0 & P1 architecture problems.

## NOW — Next Feature Development

9. [x] Finish Bills module (Phase 8).
10. [x] Finish Progress module (Phase 9).
11. [x] Finish Photos/GPS/Documents (Phase 10).
12. [x] Finish Reminders/Calendar (Phase 11).
13. [x] Validate Dashboard with new modules.
14. [ ] Validate Android (SDK/NDK resolved; Gradle Maven dependency download retry in progress).
15. [x] Validate Web/PWA (flutter build web succeeded: build\web).
16. [x] Validate Windows (flutter build windows --debug succeeded: Debug\offline_finance_management_app.exe).

## THEN SUPABASE

17. [ ] Finalize cloud schema.
18. [ ] Add Supabase Flutter integration.
19. [ ] Add Authentication.
20. [ ] Add PostgreSQL/RLS.
21. [ ] Add Storage.
22. [ ] Implement sync engine.
23. [ ] Test offline → online synchronization.

## FINAL

24. [ ] Security audit.
25. [ ] Backup/restore audit.
26. [ ] Cross-platform testing.
27. [ ] Performance testing.
28. [ ] PWA/iPhone testing.
29. [ ] Android APK build.
30. [ ] Windows distribution package.
31. [ ] Private web deployment.
32. [ ] Final client handover.

---

# 22. Definition of Done

The project is considered ready for the client only when:

- [ ] Android works offline.
- [ ] Windows works offline.
- [ ] iPhone PWA works offline after initial setup as supported by the browser.
- [ ] Local data persists after application/browser restart.
- [ ] Supabase synchronization works reliably.
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
