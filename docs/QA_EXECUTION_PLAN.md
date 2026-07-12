# WorkTrace — Manual QA Execution Plan

A short runbook for a real-Mac QA pass of the MVP. Use it together with:

- `docs/QA_CHECKLIST.md` — the full §1–§12 items and exact commands.
- `docs/QA_NOTES.md` — where results are recorded (checkbox checklist + pass log).

Goal of this pass: prove the **automatic activity capture** works end-to-end on
a real Mac — the app should show which apps/windows you used and for how long,
with no manual timing required. Manual timer, tasks and projects are **optional,
secondary** flows. **No new features** are added until this pass is green.

---

## 1. Launch the app

```
cd <repo root>
cd WorkTraceKit && swift test && cd ..          # must be green first
xcodegen generate
xcodebuild -project WorkTrace.xcodeproj -scheme WorkTrace \
  -destination 'platform=macOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Look for `BUILD SUCCEEDED` (ignore the benign `CoreSimulator is out of date`
line). Then launch the freshly built app:

```
open "$(xcodebuild -project WorkTrace.xcodeproj -scheme WorkTrace \
  -configuration Debug -showBuildSettings CODE_SIGNING_ALLOWED=NO 2>/dev/null \
  | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / FULL_PRODUCT_NAME /{n=$2} END{print d"/"n}')"
```

WorkTrace is a **menu-bar (accessory) app**: no Dock icon, no window at launch.
Find its icon in the menu bar and click it to begin. Record the exact build from
**Settings › About** (e.g. `0.1.0 (1)`) at the top of your results.

## 2. Reset to a clean state

Needed before the first-run / onboarding test (§1), and any time you want a
fresh install. **This deletes all local WorkTrace data** — back up first if it
matters.

```
# 1. Quit WorkTrace (menu-bar icon → Quit).
# 2. Delete its local data and preferences:
rm -rf ~/Library/Application\ Support/WorkTrace
defaults delete <PRODUCT_BUNDLE_IDENTIFIER> 2>/dev/null   # clears onboarding flag
```

The `WorkTrace/Backups/` folder lives inside the deleted directory, so a reset
also clears backups — export anything you want to keep first.

## 3. Permissions to grant

- **Accessibility** (required for window-title activity logging). Grant via the
  onboarding "Grant Accessibility Permission" button or System Settings ›
  Privacy & Security › Accessibility. The app re-checks on activation, so you can
  grant it while running and return.
- **Automation / Apple Events** may be prompted the first time a window title is
  read (see `NSAppleEventsUsageDescription`). Allow it.
- Note: timing and manual features must still work with Accessibility **denied**
  (titles are simply omitted) — that is an explicit test case (§12).

## 4. Flow order — test these first

The primary value is automatic activity capture. Prove that block (A) before
anything else; the optional/secondary flows (B) only matter once capture is
trusted.

### A. Automatic activity capture (primary — must pass)

Run in this order; each depends loosely on the previous:

1. **Launch the app** — menu-bar icon appears, no manual action required to
   begin recording.
2. **Grant Accessibility permission** — via onboarding or System Settings. The
   app re-checks on activation; window titles need this.
3. **Confirm automatic capture starts** — open **Today's Activity** (the primary
   screen). The status banner should read "capturing" (green). No timer start is
   needed.
4. **Switch between apps** — spend ~1 min each in Chrome, Terminal, Finder, and
   Xcode (or similar), switching windows within them.
5. **Confirm the timeline records app/window usage** — each app you used appears
   as a row with its app name and (if Accessibility granted) window title.
6. **Confirm durations are correct** — row spans (start–end) and totals roughly
   match the wall-clock time you spent; the "Active total" adds up.
7. **Confirm idle time is detected** — step away past the idle threshold; an
   idle gap row appears for that period and is not counted as active.
8. **Confirm privacy masking works before disk write** — add an exclude / mask
   rule for a sensitive app or URL, use it, then confirm the timeline shows it
   masked (eye-slash / "Private") and that **no raw title reached disk** (inspect
   the SQLite `activityEntry.windowTitle` — it must be `NULL` for masked rows).
9. **Confirm the activity summaries are visible** — the "App Usage" and
   "Window / Screen Usage" sections list totals per app and per window title,
   sorted by time.

### B. Optional / secondary flows (run only after A is green)

These are no longer the core MVP value; log failures but do not gate on task
management:

- **Manual timer (§2)** — start / count / pause-resume / stop / memo (optional).
- **Tasks & projects (§3)** — create, assign, reassign (optional; known rough).
- **Persistence & recovery (§10)** — quit/relaunch keeps activity data;
  force-quit mid-capture recovers cleanly.
- **Reports (§7)** and **CSV export (§8)** — including the export-failure alert.
- **Backup & restore (§9)** — auto/manual backup and each **restore error
  message** (missing / unreadable / non-SQLite / foreign DB) with live data left
  intact.
- **Timeline corrections (§11)** — split, merge (confirmation dialog), memo edit,
  delete.
- **Language switching (§5)** and **permission edge cases (§12)** — toggle JA⇄EN;
  confirm timing/manual features still work with Accessibility **denied** (titles
  omitted, activity still recorded).

## 5. Record pass/fail results

- Work through the checkbox checklist in `docs/QA_NOTES.md` (§1–§12 + About).
- Tick `[x]` for pass. For a failure, leave it unchecked and add a short note:
  what you did, what you expected, what happened, and the build string.
- When the run is complete, copy the checklist under a **new dated heading** in
  the QA_NOTES "Pass log" so each pass is preserved. Include the build tested.
- File anything broken as an issue with: build string, section number, repro
  steps, expected vs actual.

## 6. What blocks the MVP from moving forward

Treat these as **release blockers** — fix before adding any new work:

- **Capture does not work:** activity is not recorded automatically after launch
  (with capture enabled); apps/windows you used are missing from the timeline;
  durations are wrong; idle is not detected. This is the core MVP value.
- **Privacy violations:** any raw window title (or excluded-app data) written to
  disk; a mask that does not apply. Privacy-first is a hard product constraint.
- **Data loss or corruption:** lost/overwritten activity; a failed restore that
  damages the live DB (restore must be all-or-nothing).
- **Crash on a core flow:** launch, capture toggle, the activity timeline,
  backup, or restore.
- **Persistence failures:** activity/preferences or language/privacy settings not
  surviving a normal quit + relaunch.

Secondary (do NOT gate the MVP): manual timer glitches, task/project creation
issues (known rough), report/CSV nits.

Non-blocking (log and schedule, do not gate the MVP): copy/wording nits, minor
layout issues, one-off cosmetic glitches, and the known limitations below.

## Known limitations (expected, not bugs)

- Onboarding opens on the first menu-bar click (a menu-bar app has no launch
  window), not fully on its own.
- Restore copies over the live DB and force-quits; the user relaunches manually.
- Automated tests stop at the SwiftUI boundary — every item in this plan is
  unproven until a human runs it.
