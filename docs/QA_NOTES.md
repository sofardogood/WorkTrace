# WorkTrace — QA Notes

A record of a manual test pass against `docs/QA_CHECKLIST.md`. This file is
updated each pass. It separates what is **verified by automated tests / code
inspection** (done here) from what still **needs a human at the machine** (the
GUI-driven checklist items, which an automated agent cannot exercise).

---

## Pass log

### 2026-07-10 — activity-first pivot, first real-Mac attempt (blocked by menu confusion)

Recorded results (as observed):

- Timeline window opens: **pass**
- Activity-first timeline visible: **fail**
- Automatic activity entries visible: **fail**
- App Usage Summary visible: **fail**
- Window / Screen Usage Summary visible: **fail**

Root cause (investigated, not a wiring bug):

- The tester opened the **secondary** menu item, which was labelled
  "今日のタイムライン… / Today's Timeline…". That opens the OLD manual-session
  view `DailyTimelineView` (the "日報を生成 / Generate Report" button and
  "合計: 0m" confirm it), which queries `session`, not `activity_entry`.
- The new activity-first screen `ActivityTimelineView` IS in the app target and
  IS wired — it is the prominent top button "本日のアクティビティ / Today's
  Activity" (`open("activity")` → `window id "activity"`), and it reads
  `activity_entry` plus the App / Window summaries.
- Capture pipeline confirmed independent of the manual timer: `AppState.bootstrap()`
  → `startCapture()` starts `WorkspaceActivityObserver` (emits immediately, then
  every `samplingIntervalSeconds`) and saves each `ActivityEntry` regardless of
  timer state.
- The two menu items had near-synonymous JA labels ("本日のアクティビティ" vs
  "今日のタイムライン"), which is what caused the wrong click.

Fix applied: relabelled the old view so it is unmistakable —
`menu.openTimeline` → "Manual Timer Log… / 手動タイマーの記録…",
`window.timeline` → "Manual Timer Log / 手動タイマーの記録". Rebuilt: BUILD
SUCCEEDED.

Re-test (2026-07-11) using the "本日のアクティビティ" button — **all pass:**

- Activity screen opens (primary button): **pass**
- Automatic capture status banner (green "自動記録中"): **pass**
- Activity rows appear after app switching + Refresh: **pass**
- App names visible (Terminal, WorkTrace, Google Chrome, HiNotes): **pass**
- Window titles visible (Chrome, Terminal — Accessibility working): **pass**
- App Usage Summary populated: **pass**
- Window / Screen Usage Summary populated: **pass**

The activity-first flow is confirmed working end-to-end on a real Mac.

Follow-up UX items raised during this pass (tracked for the next change, not
blockers): (1) menu-bar wording conflates manual-timer "not tracking" with
automatic capture — separate the two states; (2) sub-minute durations render as
"0m" — format seconds; (3) add Swift Charts visualisations + summary cards;
(4) WorkTrace self-logging dominates — separate/exclude it.

Note on empty-on-launch (expected, not a bug): the normalizer buffers the
in-progress activity and only persists an entry when the app/window **changes**
or goes idle. So a fresh launch with only WorkTrace focused shows nothing until
you switch apps and hit Refresh.

### 2026-07-09 — stabilization pass

Build & tests:

- `cd WorkTraceKit && swift test` → **55 tests, 0 failures.**
- `xcodegen generate && xcodebuild … build CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED.**
  (The `CoreSimulator is out of date` line from xcodebuild is a benign macOS
  simulator warning and does not affect the macOS app build.)

Scope of this pass: the MVP stabilization work — first-run reliability, backup
safety checks, timeline edit UX, and bilingual error presentation.

---

## Automated / code-verified

These checklist items are backed by unit tests or direct code paths and are
considered covered without a manual run:

| Checklist item | Evidence |
| --- | --- |
| §2 Start/stop, resume creates a new span, no duplicate session | `TimerEngineTests` |
| §5 Report language can differ from UI language | `StorageTests.testPreferencesPersistLanguageAcrossReload` |
| §6 Privacy masking, most-restrictive-wins, mask before storage | `PrivacyGuardTests`, `ActivityNormalizerTests` |
| §7 Daily report grouping, JA/EN titles, hidden sessions excluded | `MarkdownReportBuilderTests` |
| §8 CSV header language, minutes/billable, comma/quote escaping | `CSVExporterTests` |
| §9 Automatic backup once/day, pruning, restore replaces live DB | `MigrationAndBackupTests` |
| §9 Restore rejects missing / non-SQLite / foreign-DB files; live DB untouched on failure | `MigrationAndBackupTests.testValidate*`, `testRestoreValidatesBeforeReplacing` |
| §10 Open-session recovery after force-quit | `TimerEngineTests` recover test |
| §11 Split at offset (contiguous, totals preserved), merge next, FK-safe delete | `SessionEditingTests`, `MigrationAndBackupTests.testForeignKeySetNullOnTaskDelete` |

Stabilization changes verified by inspection:

- **First-run reliability:** `AppState.observeActivation()` re-checks the
  Accessibility grant on `didBecomeActiveNotification`; onboarding flag is
  `@AppStorage("worktrace.hasOnboarded")` so it survives relaunch; UI language
  loads from persisted preferences at init. (§1, §12)
- **Backup safety:** `BackupManager.validate(at:)` runs before every
  `restore(from:)`; each `BackupError` case maps to its own bilingual message
  (`error.backup.fileMissing` / `.notReadable` / `.notSQLite` / `.notWorkTrace`),
  and the live DB is only touched after validation passes. (§9)
- **Restore confirmation:** the confirmation dialog names the chosen file and
  states the current data will be replaced and the app will quit
  (`settings.restoreConfirm*`). (§9)
- **Timeline edit UX:** merge now requires a confirmation dialog
  (`timeline.mergeConfirm*`); split range is bounded by the stepper; both
  surface `error.splitFailed` / `error.mergeFailed` on failure. (§11)
- **Error presentation:** `App/ErrorAlert.swift` provides a bilingual
  `.errorAlert(_:)`; wired into Settings (backup/restore/export) and Timeline
  (split/merge). All `error.*` keys exist in both `en` and `ja`. (all)
- **Build identity:** Settings › About shows `CFBundleShortVersionString` +
  `CFBundleVersion` so a QA run can name the exact build. (About)

---

## Requires manual verification (human at the machine)

These GUI / permission / OS-integration items cannot be exercised by an
automated agent. Run them by hand on a real Mac and tick each box. When a run
is complete, copy this whole section under a new dated heading in the **Pass
log** above and record the result.

**Before you start:** open Settings › About and note the version/build (e.g.
`0.1.0 (1)`). Reference that exact build in every result you record.

**Priority:** §A (automatic activity capture) is the core MVP value and must
pass first. §1–§3 (onboarding, manual timer, tasks) and §5–§12 are optional /
secondary — log failures but do not gate the MVP on them (task creation is
known rough).

### §A Automatic activity capture — PRIMARY (must pass)
- [ ] Launch the app: menu-bar icon appears; no manual action needed to begin.
- [ ] Grant Accessibility (onboarding or System Settings); app re-checks on
      activation.
- [ ] Open **Today's Activity** (primary screen): status banner reads
      "capturing" (green) — capture started automatically, no timer needed.
- [ ] Switch between apps (~1 min each: Chrome, Terminal, Finder, Xcode),
      changing windows within them.
- [ ] Each app used appears as a timeline row with app name and (if Accessibility
      granted) window title; masked rows show the eye-slash / "Private" marker.
- [ ] Row spans (start–end) and the "Active total" roughly match wall-clock time.
- [ ] Step away past the idle threshold → an idle gap row appears and is not
      counted as active.
- [ ] Add an exclude / mask rule, use that app/URL, confirm the timeline shows it
      masked AND `activityEntry.windowTitle` is `NULL` on disk for masked rows
      (no raw title reached storage — masking runs before write).
- [ ] "App Usage" and "Window / Screen Usage" summaries list totals per app and
      per window title, sorted by time.

### §1 First run & onboarding (secondary)
- [ ] Clean install (no `~/Library/Application Support/WorkTrace`): onboarding
      appears the first time the menu-bar icon is opened.
- [ ] All 5 pages render (Welcome, What is tracked, Data stays local, Privacy,
      Accessibility) and page dots update.
- [ ] Back / Next navigate; Skip closes onboarding.
- [ ] "Grant Accessibility Permission" opens the system prompt; after granting
      and returning, the page shows the green "granted" state.
- [ ] Onboarding does not reappear on the next launch.
- [ ] Settings › Help › "Show intro again" re-opens onboarding.

### §2 Manual timer (optional / secondary)
- [ ] Start with no task → menu-bar glyph switches to the recording icon.
- [ ] Elapsed time counts up once per second.
- [ ] Pause then Resume creates a new span (new timeline row) for the same task.
- [ ] Stop returns to idle; icon reverts to the clock.
- [ ] Quick memo entered at start appears on the recorded session.
- [ ] Starting while already running does not create a second session.

### §3 Tasks & projects (optional / secondary — creation known rough)
- [ ] Add a project; add a task under it.
- [ ] Start a timer against that task; the name shows in the menu and timeline.
- [ ] Reassign a session to another task / "No task" from the row menu.

### §4 Activity logging — capture controls (see §A for the primary flow)
- [ ] Toggling capture off stops new entries; the banner reads "capture off";
      turning it on resumes.
- [ ] With Accessibility denied, activity is still recorded but window titles are
      omitted; the banner warns titles are omitted.
- [ ] Changing sampling interval / idle threshold restarts capture, no crash.
- [ ] Timeline rows show app name, window title, start/end, duration, and the
      idle/active distinction; masked rows are flagged.
- [ ] "App Usage" and "Window / Screen Usage" summary totals match the timeline.

### §5 Language switching (JA / EN)
- [ ] UI language → Japanese switches all visible UI immediately, no relaunch.
- [ ] Back to English restores immediately.
- [ ] "System" follows the OS language.
- [ ] Report language can differ from UI language (e.g. JA UI, EN report).

### §6 Privacy masking (JA / EN)
- [ ] "Exclude" mask for an app → that app's activity is not recorded.
- [ ] "Mask title" mask → app/domain kept, no window-title data stored.
- [ ] "Time only" mask → only the time span retained.
- [ ] Most restrictive rule wins when two masks match the same app.
- [ ] Disabling a mask stops it applying.
- [ ] Confirm raw window titles never appear on disk (hashes / omissions only).

### §7 Report generation (JA / EN)
- [ ] "Generate Report" produces a Markdown daily report for today.
- [ ] Sessions grouped by task with a correct total.
- [ ] JA report uses "業務日報"; EN uses "Daily Work Report".
- [ ] Hidden sessions (reportVisible = false) excluded.
- [ ] Report text is selectable/copyable in the sheet.

### §8 CSV export (JA / EN)
- [ ] "Export today as CSV" writes a file to the chosen location.
- [ ] Header row matches the selected report language.
- [ ] Minutes and billable flag are correct.
- [ ] Memos with commas/quotes are correctly escaped.
- [ ] A failed write (e.g. read-only location) shows the export error alert.

### §9 Backup & restore
- [ ] First launch of the day writes an automatic backup; "Last backup" shows
      a timestamp.
- [ ] A second launch the same day does not create a duplicate.
- [ ] Only the most recent N backups are kept (older pruned).
- [ ] "Back up now…" saves a `.sqlite` copy to a chosen location.
- [ ] Opening a manual backup file confirms it contains the expected data.
- [ ] "Restore from backup…" shows the confirmation naming the chosen file and
      explaining the DB will be replaced and the app will quit; on relaunch the
      restored data is present.
- [ ] **Restore error messages (each distinct):**
  - [ ] Choosing a **deleted / missing** path → "backup file could not be found".
  - [ ] Choosing an **unreadable** file → "could not be read / check permissions".
  - [ ] Choosing a **non-SQLite** file (e.g. a `.txt` renamed) → "not a database file".
  - [ ] Choosing a **foreign SQLite** DB (not WorkTrace) → "not a WorkTrace backup".
  - [ ] In every failure case the live data is unchanged after dismissing the alert.

### §10 App restart & crash recovery
- [ ] Quit and relaunch: tasks, sessions, preferences persist.
- [ ] Start a timer, force-quit, relaunch → open session recovered, still running.
- [ ] Language and privacy settings survive a restart.

### §11 Timeline corrections
- [ ] Split a closed session at a chosen offset → two contiguous rows, totals
      unchanged.
- [ ] "Merge with next" shows a confirmation dialog, then combines two rows.
- [ ] Cancelling the merge dialog leaves both rows intact.
- [ ] Edit a session memo; change persists after reload.
- [ ] Delete a session; removed and an audit entry is written.

### §12 Permissions edge cases
- [ ] With Accessibility NOT granted: timing still works, titles omitted.
- [ ] Settings shows correct granted/missing status and a working
      "Request permission" button.
- [ ] Toggling the grant in System Settings while running updates the status
      after returning to the app (no relaunch).

### About / build info
- [ ] Settings › About shows a plausible version/build and the value is
      selectable/copyable.

### Open limitations / risks

- Onboarding is triggered from `MenuBarView.task`, i.e. on first menu-bar
  interaction (a menu-bar app has no window at launch) — it will not pop up
  entirely on its own before the user clicks the icon.
- Restore copies over the live DB and force-quits the app; the user must
  relaunch manually. There is no in-place hot reload.
- Automated coverage stops at the SwiftUI boundary; every §-item above under
  "Requires manual verification" is still unproven until a human runs it.
