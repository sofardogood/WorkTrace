# WorkTrace — Manual QA Checklist

Run through this before tagging a release. It covers the MVP surface only
(manual timer, activity logging, bilingual UI, privacy, reports/export, backup,
and recovery). Test in **both languages** where a language column is shown.

Automated tests must be green first: `cd WorkTraceKit && swift test`.

Build:

```
xcodegen generate
xcodebuild -project WorkTrace.xcodeproj -scheme WorkTrace \
  -destination 'platform=macOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

(The `CoreSimulator is out of date` line xcodebuild prints is a harmless macOS
simulator warning; the macOS app build is unaffected. Look for `BUILD SUCCEEDED`.)

Launch the app that was just built:

```
open "$(xcodebuild -project WorkTrace.xcodeproj -scheme WorkTrace \
  -configuration Debug -showBuildSettings CODE_SIGNING_ALLOWED=NO 2>/dev/null \
  | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / FULL_PRODUCT_NAME /{n=$2} END{print d"/"n}')"
```

WorkTrace is a menu-bar (accessory) app: it has **no Dock icon and no window at
launch**. Look for its icon in the menu bar and click it to begin.

**Clean-slate reset** (required before the §1 first-run / onboarding test —
this deletes all local WorkTrace data, so back up first if you care about it):

```
# Quit WorkTrace first, then:
rm -rf ~/Library/Application\ Support/WorkTrace
defaults delete <PRODUCT_BUNDLE_IDENTIFIER> 2>/dev/null   # clears the onboarding flag
```

Note the exact build under test from **Settings › About** (e.g. `0.1.0 (1)`)
and record it with your results in `docs/QA_NOTES.md`.

---

## 1. First run & onboarding

- [ ] On a clean install (no `~/Library/Application Support/WorkTrace`), the
      onboarding window appears the first time the menu bar icon is opened.
- [ ] All 5 pages render: Welcome, What is tracked, Data stays local, Privacy
      protections, Accessibility permission.
- [ ] Page dots and Back / Next navigation work; Skip closes onboarding.
- [ ] "Grant Accessibility Permission" opens the system prompt; after granting
      and returning, the page shows the green "granted" state.
- [ ] Onboarding does not reappear on the next launch.
- [ ] Settings › Help › "Show intro again" re-opens onboarding.

## 2. Manual timer

- [ ] Start with no task selected → menu bar icon switches to the recording glyph.
- [ ] Elapsed time counts up once per second.
- [ ] Pause then Resume creates a new span (a new timeline row) for the same task.
- [ ] Stop returns to idle and the icon reverts to the clock.
- [ ] Quick memo entered at start appears on the recorded session.
- [ ] Starting while already running does not create a second session.

## 3. Tasks & projects

- [ ] Add a project; add a task under it.
- [ ] Start a timer against that task; the task name shows in the menu and timeline.
- [ ] Reassign a session to a different task / to "No task" from the timeline row menu.

## 4. Activity logging

- [ ] With capture enabled and Accessibility granted, switching apps produces
      activity entries (verify via generated report / timeline over time).
- [ ] Idle beyond the idle threshold does not create activity entries.
- [ ] Disabling capture in Settings stops new activity entries; re-enabling resumes.
- [ ] Changing sampling interval / idle threshold restarts capture without a crash.

## 5. Language switching                                         (JA / EN)

- [ ] Settings › UI language → Japanese switches all visible UI to Japanese
      immediately (no relaunch).
- [ ] Switching back to English restores English immediately.
- [ ] "System" follows the OS language.
- [ ] Report language can differ from UI language (e.g. JA UI, EN report).

## 6. Privacy masking                                            (JA / EN)

- [ ] Add an "Exclude" mask for an app; activity for that app is not recorded.
- [ ] Add a "Mask title" mask; app/domain kept, no window-title data stored.
- [ ] Add a "Time only" mask; only the time span is retained.
- [ ] Most restrictive rule wins when two masks match the same app.
- [ ] Disabling a mask stops it from applying.
- [ ] Confirm raw window titles never appear on disk (only hashes / omissions).

## 7. Report generation                                          (JA / EN)

- [ ] "Generate Report" produces a Markdown daily report for today.
- [ ] Sessions are grouped by task with a correct total.
- [ ] Japanese report uses "業務日報"; English uses "Daily Work Report".
- [ ] Hidden sessions (reportVisible = false) are excluded.
- [ ] Report text is selectable/copyable.

## 8. CSV export                                                 (JA / EN)

- [ ] Settings › Data › "Export today as CSV" writes a file to the chosen location.
- [ ] Header row matches the selected report language.
- [ ] Minutes and billable flag are correct.
- [ ] Memos containing commas/quotes are correctly escaped.

## 9. Backup & restore

- [ ] First launch of the day creates an automatic backup under
      `…/WorkTrace/Backups/`; "Last automatic backup" shows a timestamp.
- [ ] A second launch the same day does not create a duplicate backup.
- [ ] Only the most recent N backups are kept (older ones pruned).
- [ ] "Back up now…" saves a `.sqlite` copy to a chosen location.
- [ ] Opening a manual backup file confirms it contains the expected data.
- [ ] "Restore from backup…" shows the confirmation dialog, then quits the app;
      on relaunch the restored data is present.

## 10. App restart & crash recovery

- [ ] Quit and relaunch: existing tasks, sessions and preferences persist.
- [ ] Start a timer, force-quit the app, relaunch → the open session is recovered
      and still running (no lost time).
- [ ] Language and privacy settings survive a restart.

## 11. Timeline corrections

- [ ] Split a closed session at a chosen minute offset → two contiguous rows,
      totals unchanged.
- [ ] "Merge with next" combines two adjacent sessions into one spanning row.
- [ ] Edit a session memo; the change persists after reload.
- [ ] Delete a session; it is removed and an audit entry is written.

## 12. Permissions edge cases

- [ ] With Accessibility NOT granted, timing still works; window titles are omitted.
- [ ] Settings shows the correct granted/missing status and a "Request permission" button.
