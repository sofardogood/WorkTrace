# Security Policy

WorkTrace handles sensitive local activity metadata. Security and privacy reports are taken seriously, even when the affected behavior appears limited to a single device.

## Supported versions

Until the first stable release, security fixes are provided for the latest release and the current `main` branch.

| Version | Supported |
|---|---|
| `main` | Yes |
| Latest `0.x` release | Yes |
| Older releases | No |

## Reporting a vulnerability

Please do not open a public issue for vulnerabilities that could expose activity data, window titles, local database contents, backup files, or privilege boundaries.

Use GitHub's private vulnerability reporting feature for this repository when available. If it is unavailable, contact the maintainer through the public GitHub profile and request a private reporting channel without including exploit details in the first message.

A useful report includes:

- Affected commit or version
- macOS and Xcode versions
- Reproduction steps
- Expected and observed behavior
- Potential data exposure or privilege impact
- Suggested mitigation, if known

## Response targets

The maintainer aims to:

- Acknowledge a report within 3 business days
- Confirm severity and scope within 7 business days
- Publish a fix or mitigation plan as soon as practical

These are targets, not contractual guarantees.

## Security boundaries

The following areas deserve particular scrutiny:

- Accessibility permission handling
- Capture and normalization of window titles
- Privacy masking before persistence
- SQLite migrations and retention cleanup
- Backup validation and restore behavior
- Audit-log integrity
- Any future optional AI or network integration

## Privacy commitments

WorkTrace does not intentionally capture screenshots or keystrokes. Activity data is stored locally. Masked values must not be reconstructed, and sensitive values should be filtered before disk persistence.
