# WorkTrace (worklog-os)

A **local-first macOS work-log app**. Records activity, manages tasks and work
sessions, and produces bilingual (Japanese / English) reports and exports.

This repository currently contains the **MVP foundation**: a menu-bar app with a
manual timer, task/project management, a local SQLite database, basic activity
logging, a daily timeline, full JA/EN UI switching, and Markdown/CSV reports.
Advanced features (AI reports, automation discovery, external integrations, team
mode) are intentionally **not** implemented yet — the code is structured so they
can be added later without reworking the core.

> Based on the specification `Timemator自作版_日英対応_設計仕様書.docx` (WorkTrace AI, v2.0).

---

## Requirements

- **macOS 26.5+** (deployment target is `26.5`; patch builds such as 26.5.1 are
  covered — Xcode deployment targets use `major.minor` granularity, so `26.5.1`
  itself is not a selectable target).
- **Xcode 26.5+**, Swift 6.3 toolchain.
- [**XcodeGen**](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`.

## Setup

```bash
# 1. Generate the Xcode project from project.yml
xcodegen generate

# 2a. Build & test the core package (no UI)
cd WorkTraceKit && swift test && cd ..

# 2b. Build the app
xcodebuild -project WorkTrace.xcodeproj -scheme WorkTrace \
  -destination 'platform=macOS' -configuration Debug build

# Or just open it:
open WorkTrace.xcodeproj
```

The generated `WorkTrace.xcodeproj` is **git-ignored** — always regenerate it
with `xcodegen generate` after pulling changes to `project.yml`.

### Permissions
On first launch the app runs as a menu-bar item (no Dock icon). To capture
window titles it needs **Accessibility** permission:
System Settings › Privacy & Security › Accessibility. Without it, the app still
works — window titles are simply omitted. No screenshots or keystrokes are ever
captured.

### Data location
`~/Library/Application Support/WorkTrace/worktrace.sqlite` (WAL mode).

---

## Architecture

The system is split into strictly layered modules. **Dependencies only point
downward** — `WTCore` depends on nothing and is the stable data model everything
else reads.

```
App (SwiftUI menu-bar UI)
      │  wires everything together in AppState (composition root)
      ▼
WTObservation  WTNormalization  WTSession  WTReporting  WTAI
   (capture)     (privacy/norm)   (timer)   (md/csv)   (protocols only)
      │              │              │          │          │
      └──────────────┴──────┬───────┴──────────┴──────────┘
                            ▼
                        WTStorage  ──►  WTCore
                     (GRDB/SQLite)     (models, enums)
```

| Module | Responsibility | Key types |
|---|---|---|
| **WTCore** | Pure domain model. No dependencies. | `Project`, `WorkTask`, `Session`, `ActivityEntry`, `PrivacyMask`, `UserPreferences`, `AuditLog`, enums |
| **WTStorage** | SQLite via GRDB: migrations, repositories, audit. Isolates the storage engine. | `AppDatabase`, `*Repository`, `AuditLogWriter` |
| **WTObservation** | Captures active app / window title / idle. | `ActivityObserving`, `WorkspaceActivityObserver` |
| **WTNormalization** | Masks & compresses activity **before** it is stored. | `PrivacyGuard`, `ActivityNormalizer` |
| **WTSession** | Manual-timer state machine + crash recovery. | `TimerEngine`, `TimerState` |
| **WTReporting** | Deterministic bilingual Markdown / CSV. | `MarkdownReportBuilder`, `CSVExporter` |
| **WTAI** | AI **seam only** — protocols + no-op stubs. No LLM yet. | `ReportGenerating`, `ActivityClassifying`, `Noop*` |

### Design principles enforced here
- **Stable event/session model** — `Session` and `ActivityEntry` are the
  foundation everything downstream reads; getting them right now avoids costly
  migrations later.
- **Privacy before disk** — the capture pipeline runs `PrivacyGuard` inside
  `ActivityNormalizer.ingest(_:)`, so raw window titles / URLs are hashed or
  dropped *before* `WTStorage` ever writes them.
- **AI behind protocols** — the MVP uses deterministic report/CSV builders. A
  local (default) or cloud LLM is added later behind `WTAI`'s protocols with no
  caller changes.
- **Bilingual is structural** — UI strings live in `App/Localization/Localizable.xcstrings`
  driven by a runtime-switchable locale; *report* language is a separate
  `ReportLanguage` parameter, so a Japanese UI can emit an English report.
- **Storage swappable** — GRDB is confined to `WTStorage`. A future SQLCipher
  encryption option plugs into `AppDatabase` without touching callers.

---

## What's implemented (MVP)

- [x] Menu-bar app, manual timer (start / pause / resume / stop / memo)
- [x] Local SQLite (GRDB) with WAL, migrations, backups path, audit log
- [x] Project / task management
- [x] Basic activity logging (app name, window title hash, idle)
- [x] Privacy zones (exclude / mask / time-only) applied before writing to disk
- [x] Daily timeline (reassign task, edit memo, delete)
- [x] Deterministic daily Markdown report + CSV export (JA / EN)
- [x] Full Japanese / English UI switching
- [x] Session crash recovery

## Deliberately deferred (design seams in place)
AI classification & report generation · automation-candidate discovery ·
natural-language search · project profit / billing analysis · calendar / Slack /
GitHub / Notion integrations · team dashboard · at-rest DB encryption (SQLCipher).

See §14 of the spec for the "do NOT build" list (no screenshots, no keylogging,
no per-employee surveillance) — these constraints are respected by design.

---

## Tests

```bash
cd WorkTraceKit && swift test
```

Covers the core model, storage round-trips / migrations, and the timer state
machine (including pause/resume spans and crash recovery).
