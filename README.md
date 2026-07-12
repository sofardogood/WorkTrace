# WorkTrace

[![CI](https://github.com/sofardogood/WorkTrace/actions/workflows/ci.yml/badge.svg)](https://github.com/sofardogood/WorkTrace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-26.5%2B-black)](#requirements)

**WorkTrace is a privacy-first, local-only activity tracker for macOS.** It records foreground applications and readable window titles, helps users understand how time was spent, and keeps the activity database on the Mac.

The project is designed for people who want useful work analytics without sending detailed behavior data to a surveillance-style cloud service.

## Why WorkTrace

Many time-tracking tools require manual timers, store detailed activity remotely, or provide little control over sensitive window titles. WorkTrace takes a different approach:

- Automatic activity capture is the primary experience
- Privacy rules run before sensitive values are persisted
- Activity data remains in a local SQLite database
- The default retention window is seven calendar days
- Charts explain composition, ranking, chronology, and trends separately
- Japanese and English are supported throughout the interface

WorkTrace does **not** intentionally capture screenshots or keystrokes.

## Current capabilities

### Automatic activity review

- Foreground application and window-title capture
- Daily and rolling seven-day views
- Active time, idle time, app switches, top app, and top window summaries
- Overview, Applications, Windows & Screens, Timeline, and Trends sections
- Donut charts for active/idle and app-share composition
- Horizontal rankings for apps and windows
- Chronological Gantt-style timeline with idle gaps
- Search and filters for application, title, and masking state
- WorkTrace self-time excluded from normal productivity summaries but retained in detailed rows

### Data lifecycle and privacy

- Local SQLite storage through GRDB
- Privacy modes: exclude, mask title, and time-only
- Masking applied before disk persistence
- Default retention: today plus the previous six calendar days
- Configurable retention: 7, 30, 90, 180, or 365 days, or indefinitely
- Backup before automatic retention cleanup
- Audit record for cleanup operations
- Masked values are never reconstructed

### Manual organization and reporting

- Manual timer with start, pause, resume, stop, memo, and crash recovery
- Project and task management
- Deterministic Markdown reports and CSV export
- Japanese and English report generation
- Locale-aware seconds, minutes, and hours formatting

### Quality baseline

- 90 automated tests
- XcodeGen-based reproducible project generation
- Layered Swift package architecture
- Public contribution, security, roadmap, and release documentation

## Privacy model

WorkTrace uses macOS Accessibility permission only to read the title of the active window. Without Accessibility permission, application activity still works, but window titles are omitted.

No screenshots or keystrokes are collected. No cloud account is required. No hidden telemetry is included.

The local database is stored at:

```text
~/Library/Application Support/WorkTrace/worktrace.sqlite
```

Do not attach that database or raw activity logs to public issues.

## Requirements

- macOS 26.5 or later
- Xcode 26.5 or later
- Swift 6.3 toolchain
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

Install XcodeGen with Homebrew:

```bash
brew install xcodegen
```

## Build and test

```bash
git clone https://github.com/sofardogood/WorkTrace.git
cd WorkTrace

xcodegen generate
swift test --package-path WorkTraceKit

xcodebuild \
  -project WorkTrace.xcodeproj \
  -scheme WorkTrace \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

The generated `WorkTrace.xcodeproj` is intentionally ignored. Regenerate it after cloning or after changes to `project.yml`.

## Architecture

```text
App (SwiftUI menu-bar UI)
      │
      ▼
WTObservation  WTNormalization  WTSession  WTReporting  WTAI
   capture        privacy          timer      analytics   interfaces
      │               │              │            │           │
      └───────────────┴──────┬───────┴────────────┴───────────┘
                             ▼
                         WTStorage ──► WTCore
                         GRDB/SQLite   domain model
```

| Module | Responsibility |
|---|---|
| `WTCore` | Dependency-free domain models, preferences, retention, formatting, audit types |
| `WTStorage` | SQLite migrations, repositories, backups, cleanup, and audit persistence |
| `WTObservation` | Active application, window-title, and idle observation |
| `WTNormalization` | Privacy filtering and activity compression before persistence |
| `WTSession` | Manual timer and session editing |
| `WTReporting` | Activity analytics, filtering, summaries, Markdown, and CSV |
| `WTAI` | Optional future integration interfaces; no required LLM dependency |

## Project maintenance

- [Contributing guide](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)
- [Roadmap](ROADMAP.md)
- [v0.1.0 release notes](RELEASE_NOTES_v0.1.0.md)
- [Issue tracker](https://github.com/sofardogood/WorkTrace/issues)

Bug reports and pull requests should never include private window titles, activity databases, credentials, or local user paths.

## Release status

`v0.1.0` is the first public release baseline. Signed and notarized downloadable builds are planned; until then, the verified installation path is building from source.

## License

WorkTrace source code is available under the [MIT License](LICENSE).
