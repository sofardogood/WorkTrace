# Contributing to WorkTrace

Thank you for helping improve WorkTrace. The project welcomes bug reports, documentation fixes, test improvements, and focused feature proposals.

## Before opening a pull request

1. Search existing issues and pull requests.
2. Open or reference an issue for non-trivial changes.
3. Keep each pull request focused on one problem.
4. Preserve WorkTrace's privacy boundaries.

## Privacy invariants

Changes must not introduce:

- Screenshot capture
- Keystroke logging
- Upload of activity logs or window titles by default
- Reconstruction of masked titles
- Hidden telemetry
- Per-employee surveillance features

Privacy rules must be applied before sensitive values are written to disk.

## Development setup

Requirements:

- macOS 26.5 or later for the app target
- Xcode 26.5 or later
- XcodeGen

```bash
brew install xcodegen
xcodegen generate
swift test --package-path WorkTraceKit
xcodebuild \
  -project WorkTrace.xcodeproj \
  -scheme WorkTrace \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

The generated `WorkTrace.xcodeproj` is intentionally not committed. Regenerate it after changes to `project.yml`.

## Architecture boundaries

- `WTCore`: dependency-free domain types
- `WTStorage`: GRDB and SQLite access
- `WTObservation`: foreground app and window observation
- `WTNormalization`: privacy filtering and activity normalization
- `WTSession`: manual timer behavior
- `WTReporting`: deterministic analytics and exports
- `WTAI`: interfaces only; no required cloud dependency

Avoid bypassing these layers for convenience. Small shortcuts become large maintenance rituals later.

## Tests

All behavior changes should include or update tests. The current suite contains 90 tests covering retention, privacy, storage, backups, analytics, filtering, formatting, and timer behavior.

Run:

```bash
swift test --package-path WorkTraceKit
```

## Localization

User-facing strings must be available in both Japanese and English through `App/Localization/Localizable.xcstrings`.

## Pull request checklist

- Tests pass locally
- New behavior is tested
- Japanese and English strings are updated
- No private data, local databases, credentials, or absolute user paths are committed
- Privacy behavior is unchanged or explicitly documented
- README and CHANGELOG are updated when appropriate

## Commit style

Use concise, imperative commit messages, for example:

- `fix: preserve masked activity during filtering`
- `feat: add seven-day trend comparison`
- `docs: clarify accessibility permission`
- `test: cover retention cleanup boundary`
