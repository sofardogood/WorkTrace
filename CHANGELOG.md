# Changelog

All notable changes to WorkTrace are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows semantic versioning where practical during the `0.x` phase.

## [Unreleased]

### Planned

- Signed and notarized release packaging
- Public screenshots and installation guide
- Additional accessibility and backup hardening
- Contributor-driven bug fixes and localization improvements

## [0.1.0] - 2026-07-12

### Added

- Automatic foreground application and window-title activity capture
- Privacy filtering before activity metadata is written to disk
- Configurable privacy modes: exclude, mask title, and time-only
- Local SQLite storage using GRDB with migrations and WAL mode
- Seven-day default retention with configurable retention periods
- Backup creation before retention cleanup
- Audit logging for cleanup and other maintenance actions
- Daily and seven-day activity views
- Overview, Applications, Windows & Screens, Timeline, and Trends sections
- Donut charts for active/idle composition and application share
- Horizontal usage rankings and chronological activity timeline
- Active time, idle time, app-switch count, and top-app summaries
- Manual timer with start, pause, resume, stop, memo, and crash recovery
- Project and task management
- Deterministic Markdown and CSV reports
- Full Japanese and English interface support
- Locale-aware duration formatting
- 90 automated tests covering privacy, retention, analytics, storage, backups, exports, and timer behavior
- XcodeGen-based reproducible project generation

### Security and privacy

- No screenshot capture
- No keystroke capture
- No required cloud service
- Masked titles are never reconstructed
- WorkTrace's own foreground time is excluded from normal productivity summaries while remaining visible in detailed rows

[Unreleased]: https://github.com/sofardogood/WorkTrace/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sofardogood/WorkTrace/releases/tag/v0.1.0
