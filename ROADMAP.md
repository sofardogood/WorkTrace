# WorkTrace Roadmap

This roadmap describes intended maintenance and product directions. It is not a promise of dates or specific implementations.

## v0.1.x: Public release hardening

- Signed and notarized macOS distribution
- Release archive and checksum generation
- Screenshot-based installation guide
- Better empty states and accessibility labels
- Additional backup and restore edge-case tests
- CI coverage for the Swift package and app build where runner support permits
- First external bug reports and contributor pull requests

## v0.2: Activity review quality

- Better correction and annotation workflows
- More robust app and window grouping
- Export improvements for daily and weekly summaries
- Performance profiling for longer retention periods
- Additional privacy presets and clearer data-lifecycle controls

## v0.3: Local intelligence experiments

Any intelligence feature must preserve the local-first model and remain optional.

Potential work:

- Local activity classification
- Local daily-summary assistance
- Local automation-candidate suggestions
- Explicit user-controlled export to external models

Raw activity logs and window titles must not be uploaded by default.

## Ongoing maintenance

- Triage issues and reproduce reported bugs
- Review pull requests
- Maintain Japanese and English documentation
- Monitor dependency and macOS compatibility changes
- Publish release notes and security fixes
- Expand tests around privacy and persistence boundaries

## Non-goals

WorkTrace is not intended to become:

- Employee surveillance software
- A keystroke logger
- A screenshot recorder
- A hidden telemetry collector
- A cloud-required productivity service
