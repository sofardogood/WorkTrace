# WorkTrace v0.1.0

WorkTrace v0.1.0 is the first public release of a local-first macOS activity tracker focused on user control, privacy before persistence, and transparent work-pattern review.

## Highlights

- Automatic foreground app and window-title tracking
- Local-only SQLite storage
- Seven-day default retention with configurable cleanup
- Privacy masking before data is written to disk
- Daily and seven-day analytics
- Donut charts, ranking bars, trends, and chronological timeline
- Japanese and English interface support
- Manual timer, project/task organization, Markdown reports, and CSV export
- 90 automated tests

## Privacy model

WorkTrace does not intentionally capture screenshots or keystrokes. It does not require a cloud account. Window-title privacy rules are applied before persistence, and masked values are not reconstructed.

Accessibility permission is used only to read the active window title. Without that permission, the app continues to record application activity while omitting titles.

## Requirements

- macOS 26.5 or later
- Apple silicon is the currently verified build target

## Build from source

```bash
brew install xcodegen
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

## Known limitations

- The first public release is distributed from source until signed and notarized binaries are available.
- The app currently targets recent macOS and Xcode versions.
- No cloud synchronization or AI classification is enabled.
- External contributor workflows are newly established and will mature through public issue and pull request activity.

## Verification

The release baseline passes 90 Swift package tests and a macOS arm64 application build.

## Feedback

Please use GitHub Issues for reproducible bugs and focused feature requests. Do not attach raw activity databases, private window titles, credentials, or other sensitive data.
