# Pester testing

This is the physical-device test checklist. The current development build is `0.6.1-0046`; the latest completed build is `0.5.0-0018`. Update the checkboxes and results as each feature or bug is tested. Record the device model, iOS version, app build, notification settings, and smartwatch state when a result is surprising.

## v0.6.1 task details sheet

Build `0.6.1-0026` is a visual prototype rather than an accepted test candidate. The content direction remains useful, but the sheet needs another design pass before the checklist below is run. Build `0.6.1-0044` includes the inbox-title refinements through `0037`, 53-point icon-only action controls with neutral circular borders and exact visible hit areas, plus a single bordered title/due card whose full title surface opens the title editor. Build `0.6.1-0046` adds five-minute due-time controls for new tasks and editing; the visual composition remains open for review before device testing.

- [ ] Review the overall task-details composition before functional device testing.
  - *Expect* a focused, lightweight surface that presents only the task information and controls needed for this interaction.
  - *User notes:* hmm it doesnt looks right. I think you are to context heavy.
  - *User notes:* hmm not quite. It's definitely getting better, but looks weird; here's my observations:
    1. Action buttons are too tall (need more spacing at the top.
    2. Can the half sheet be smaller? There is a lot of empty space now.
    3. The title and date dont look like they fit I am thinking of borders and the date will ahve a grayer box behind it. See picture:
    4. The duration row just looks weird still. Still thinking of a better solution. Maybe just leave it until the above are handled.
    5. I dont like the color behing the action buttons. Just use the default color of the button and the icon be the only color.

- [ ] Tap tasks from Pestering, Upcoming, and Completed.
  - *Expect* each task to open in a compact, 340-point bottom sheet with a visible drag indicator. Expect the sheet to expand to full height when dragged and dismiss with the in-sheet Close control or a downward gesture.
  - *User notes:*
- [ ] Review an Active, Snoozed, Overdue, Upcoming, and Completed task in the sheet.
  - *Expect* a concise action bar first, with lifecycle actions when applicable plus Delete and Close, followed by title, original due timestamp, pester duration, and snooze duration. Next-pester time, lifecycle status, pester count, task ID, and interaction log should not appear.
  - *User notes:*
- [ ] Review an active task without scrolling the sheet.
  - *Expect* evenly spaced icon-only Complete, Snooze, Delete, and Close controls with generous top spacing. Complete uses a green checkmark, Snooze a blue moon, Delete a red trash can, and Close a subdued gray X; all icons sit inside subtle neutral circular outlines with no colored fills, and Delete still requires confirmation.
  - *User notes:*
- [ ] Open both duration menus.
  - *Expect* a bell for Pester and timer for Snooze with compact current minute values below them, and exactly 1, 2, 3, 4, 5, 10, 15, 20, 30, 45, and 60 minute choices. Selecting a value saves that property immediately and updates only that task’s notification schedule.
  - *User notes:*
- [ ] Use Snooze and Complete from the details sheet.
  - *Expect* the action to affect only that task, dismiss the sheet, and move the task to its correct inbox or Completed location.
  - *User notes:*
- [ ] Tap anywhere in the title-card surface, edit the title directly in the task sheet, and save it without changing the due date.
  - *Expect* a focused Edit Title mode with Cancel and Save. Saving updates the title in the app and remaining notifications without changing task state, next-alert time, pester count, or pending notification timing. Cancel discards the draft.
  - *User notes:*
- [ ] Tap the due date, choose a future date and time, and save it.
  - *Expect* a focused Reschedule mode containing only date and time controls with Cancel and Set. The time control offers only five-minute values (for example, :00, :05, :10, and :15). Set reschedules that task and leaves unrelated tasks unchanged; Cancel preserves the old schedule.
  - *User notes:*
- [ ] Create a new task and edit an existing task through the standard task form.
  - *Expect* both Due controls offer only five-minute values. A new task’s initial due time rounds up to the next five-minute boundary; saving either form preserves the chosen five-minute due time.
  - *User notes:*
- [ ] Start Delete task from the sheet, cancel once, then confirm it.
  - *Expect* the short confirmation to omit the potentially long task title. Cancel keeps the task; confirmation removes the task and its notifications and dismisses the sheet.
  - *User notes:*
- [ ] Repeat the sheet tests in light and dark appearance and with larger Dynamic Type.
  - *Expect* readable values, 44-point controls, visible menu selections, and no clipped or hidden actions at either sheet height.
  - *User notes:*

## v0.6.0 finalized inbox grouping

- [x] Tap the visible and blank areas of an inbox task row, including the space immediately before the chevron.
  - *Expect* the entire row opens that task without interfering with its swipe actions.
  - *User notes:* ok perfect. That tested good.
- [ ] Open Pester with Overdue, Active, Snoozed, Upcoming-today, and Upcoming-future tasks.
  - *Expect* only Pestering and Upcoming task-section headers. Pestering contains Overdue, Active, and Snoozed tasks. Upcoming contains both tasks due today and tasks due later. There should be no separate Snoozed, Today, Future, or Unscheduled header.
  - *User notes:*
- [ ] Create multiple Pestering tasks in deliberately mixed order.
  - *Expect* all Overdue tasks first, then Active tasks, then Snoozed tasks. Within each state, expect the earliest next pester or snooze time first; equal times use the oldest creation time first.
  - *User notes:*
- [ ] Create multiple Upcoming tasks due today and in the future in deliberately mixed order.
  - *Expect* one chronological list using next pester time, followed by oldest creation time when dates match. Tasks due today use a green clock; later tasks use the existing blue clock. The displayed date and status must keep the distinction understandable without color.
  - *User notes:*
- [ ] Let an Upcoming task begin, snooze an Active task, and complete another task.
  - *Expect* the first task to move from Upcoming to Pestering, the snoozed task to remain in Pestering but sort after Active tasks, and the completed task to move to the existing Completed screen.
  - *User notes:*
- [ ] Add and edit tasks through the normal task forms.
  - *Expect* every saved task to require a future date and time. No Unscheduled task or inbox section should be created.
  - *User notes:*
- [x] Review the inbox section headers and Completed row in light and dark appearance.
  - *Expect* plain text Pestering and Upcoming headers without colored dots. Expect the Completed checkmark to use the subdued system secondary color rather than green.
  - *User notes:* This is looking good. ✅ Simulator validation passed in light and dark appearance; physical-iPhone testing will follow later.

## v0.5.0 inbox grouping and ordering

- [x] Launch Pester from Xcode with several tasks in different states, then background and reopen it several times.
  - *Expect* no `NavigationRequestObserver tried to update multiple times per frame` warning. Expect every section and NavigationLink to remain responsive.
  - *User notes:* Build `0.5.0-0015` logged the warning on its first physical-phone run.
  - *User notes 2:* Confirmed after fix ✅
- [x] Create tasks due today and on a future date, then keep one completed or Not scheduled task.
  - *Expect* nonempty inbox sections to appear in this order: Pestering, Snoozed, Today, Future, Unscheduled. Active and Overdue tasks belong to Pestering. Only Upcoming tasks due today belong to Today. Completed tasks do not appear among the inbox task sections.
  - *User notes:* ✅
- [x] Check the section indicators in light and dark appearance.
  - *Expect* Pestering to use red, Snoozed purple, Today green, and Future and Unscheduled gray. Text and state icons must remain readable without relying on section color alone.
  - *User notes:* ✅
- [x] Create at least three Today tasks and three Future tasks in a deliberately mixed order.
  - *Expect* each section to sort by the task's next pester or scheduled time, earliest first. Tasks with identical times should sort by title.
  - *User notes:* ✅
- [x] Snooze an active Pestering task.
  - *Expect* it to move immediately from Pestering into Snoozed and sort by its fixed snooze deadline. Other task schedules must remain unchanged.
  - *User notes:* ✅
- [x] Let a snoozed task reach its deadline and begin pestering, then open Pester.
  - *Expect* it to move from Snoozed to Pestering and show the correct next pester time.
  - *User notes:* ok great all the sorting and grouping is working. ✅
- [x] Let a task exhaust all eight notifications, then open Pester.
  - *Expect* it to appear in Pestering with an Overdue row status while Pester is open, then restart at Pester 1/8 when leaving the app according to the established overdue-reset behavior.
  - *User notes:* ✅
- [x] Complete, reschedule, and delete tasks from different sections.
  - *Expect* each affected task to move or disappear immediately, with no duplicate row or stale section. Unrelated tasks and notification schedules must remain unchanged.
  - *User notes:* ✅ partial tested. Will continue testing this in real world use.
- [x] Change the timing of an upcoming task.
  - *Expect* it to move between Today and Future when appropriate, sort at its new time, and produce notifications only from the replacement schedule.
  - *User notes:* ok great all the sorting and grouping is working. ✅
- [x] Complete a task, then open the Completed row at the bottom of the inbox.
  - *Expect* the completed task to disappear from the inbox sections immediately. Expect the Completed row to show the total count and open a dedicated screen where completed tasks are sorted by most recently completed first and remain tappable.
  - *User notes:* ok great all the sorting and grouping is working. ✅

## v0.4.2 deletion controls

- [x] Open an active or upcoming task and inspect its management actions.
  - *Expect* Delete task to be the only removal action; there should be no separate Cancel notification schedule option.
  - *User notes:* I dont actually want a cancel option. In my opinion cancel and delete are the same functionality. This will make more sense during the cleanup phase (v0.6)
- [x] Open a task and tap Delete task.
  - *Expect* a permanent-deletion confirmation. Cancel it once and confirm it the second time; expect the task and all of its pending and delivered notifications to be removed.
  - *User notes:* ✅ Cofirmed
- [x] Swipe a middle task row left as far as possible, tap Delete, and cancel the confirmation. Repeat with the last row.
  - *Expect* both rows to remain in place while their confirmation is visible and after it is canceled. The selected row should remain highlighted behind the short confirmation dialog. Rows below the middle task must not shift up and redraw. Repeat on a middle row and confirm deletion; expect the list to close the gap only after confirmation.
  - *User notes:* Prior build `0.4.2-0011`: 🐛 The swipe doesnt fully remove the row now, but when you click delete it does remove it and then makes it come back when the confirmation box comes up. See video I took on my phone
	  - Interestingly enough the swipe + delete button on the last task in the list doesnt change the list. See video from above.
  - *User notes:* ✅ Build `0.4.2-0014` keeps the row in place and the selected-row highlight looks correct.

## v0.4.1 snooze display

- [x] Snooze an active task and leave Pester open through the snooze deadline.
  - *Expect* the inbox and task detail to show a fixed `Snoozed until` time while the task is Snoozed. After the deadline, expect the task to become Active and show its moving `Next` pester time.
  - *Expect* a task snoozed at 09:02 for 10 minutes with a 1-minute pester duration to show 09:12 while snoozed, 09:13 after Pester 1/8, and 09:14 after Pester 2/8. It must not jump to 09:23 or 09:25.
  - *User notes:* ✅ Times update properly and the notification behavior remains correct.
- [x] Snooze a task, then change its pester and snooze durations before the original snooze deadline.
  - *Expect* the task to remain Snoozed until its original deadline. Expect `Snoozed until` to remain fixed while the replacement batch adopts the new pester duration after that deadline.
  - *User notes:* ✅ Functionality remains correct after the display-time fix.
- [x] Close and reopen Pester while a task is snoozed.
  - *Expect* the same fixed `Snoozed until` time to remain visible after relaunch.
  - *User notes:* ✅ Confirmed working

**Proposed State**
08:55 - Create new task for 09:00
	- Display: Next Pester time: 09:00
09:00 - Pester 1/8 happens
	- Display: Next Pester time: 09:01
09:01 - Pester 2/8 happens
	- Display: Next Pester time: 09:02
09:02 - Pester 3/8 happens
	- Display: Next Pester time: 09:03
	- *User Snoozes (10 mins)*
	- Display: Next pester time: 09:12
		- Because it's 09:02 and the user wants to snooze for 10 mins
09:03 - No changes
	- Display: Next pester time: 09:12
09:04 - No changes
	- Display: Next pester time: 09:12
....
09:12 - Pester 1/8 happens
	- Display: Next Pester time: 09:13
		- Because its not active and the next pester time should be set
09:13 - Pester 2/8 happens
	- Display: Next Pester time: 09:14

**Current State:**
08:55 - Create new task for 09:00
	- Display: Next Pester time: 09:00
09:00 - Pester 1/8 happens
	- Display: Next Pester time: 09:01
09:01 - Pester 2/8 happens
	- Display: Next Pester time: 09:02
09:02 - Pester 3/8 happens
	- Display: Next Pester time: 09:03
	- *User Snoozes (10 mins)*
	- Display: Next pester time: 09:12
		- Because it's 09:02 and the user wants to snooze for 10 mins
09:03 - No changes
	- Display: Next pester time: 09:12
09:04 - No changes
	- Display: Next pester time: 09:12
....
09:12 - Pester 1/8 happens
	- Display: Next Pester time: 09:23 (should be 09:13)
	- 🐛 Doesnt properly update the display time from this point on
09:13 - Pester 2/8 happens
	- Display: Next Pester time: 09:25 (should be 09:14)
09:14 - Pester 1/8 happens
	- Display: Next Pester time: 09:27 (should be 09:15)
09:15 - Pester 2/8 happens
	- Display: Next Pester time: 09:29 (should be 09:16)

Title-only edits still reschedule the task in this build. That cleanup is intentionally deferred to v0.6.0.

## v0.4.0 task inbox

- [x] Install `0.4.0-0008` over the tested `0.3.1-0005` build.
  - *Expect* Reminder A and Reminder B, including their settings and any pending schedules, to remain available.
  - *User notes*: ✅ Worked as expected.
- [x] Tap Add and create a task with a unique title, a future due time, and distinct pester and snooze durations.
  - *Expect* the task to appear in the inbox as Upcoming and its first notification to arrive at the chosen due time.
  - *Expect* later notifications to follow the task's pester duration and show the correct title.
  - *User notes* : 🐛 When clicking on the '+' button it froze and generated some errors in the output.
- [x] After force-quitting Pester, launch it and open the New Task screen three times.
  - *Expect* the New Task screen to open promptly each time without blocking input.
  - *User notes:* The first opening on `0.4.0-0008` paused for several seconds and logged `System gesture gate timed out`, `Result accumulator timeout`, and repeated `Reporter disconnected` messages. Record whether the delay happens only on the first opening, on every opening, or only while attached to Xcode. Also try one launch directly from the phone without Xcode attached.
  - *User notes:* ✅ Force closing while un-attached from xcode; did NOT produce delay
	  - ✅ Force closing app & restarting phone; did NOT produce delay
	  - 🐛 Force closing while attached to Xcode; produced DELAY
	  - 🐛 Re-building app from Xcode while attached; produced DELAY
	  - Re-building app from Xcode and unattaching; this one is tough because it still stays attached to Xcode even after unplugging so im not sure if there is something else going on but it created delays.
- [x] Create at least two new tasks with different settings.
  - *Expect* each task to retain its own title, due time, pester duration, snooze duration, state, and notification batch.
  - *User notes:* ✅ Works as expected
- [x] Close and reopen Pester, then force-quit and reopen it.
  - *Expect* all created tasks and their properties to remain present without duplicate tasks or schedules.
  - *User notes:* ✅ Works as expected
- [x] Restart the iPhone while a created task is upcoming.
  - *Expect* the task and its schedule to survive, and its notification to arrive.
  - *User notes:* ✅ Works as expected
- [x] Edit a task's title, due time, pester duration, and snooze duration.
  - *Expect* the inbox and detail screen to show the new values immediately.
  - *Expect* no notification at the old due time; the replacement batch should use the new title and timing.
  - *User Notes:* 🐛 When editing the object it re-creates the scheduled task and moves it to upcoming. All I did was change the title. It should detect that I didnt change the date/time so the status and pester times should not change. Let's talk about this one before fixing it
  - 🐛 When a task is snoozed and you change the pester time and snooze time it remains in the snoozed state.
  - 🐛 There is some weird logic going on with snoozed tasks that have their pester/snooze time changed while snoozed. I need to replicate this before moving on or fixing this bug.
  - *User testing:* Created new task (scheduled for today 09:00). Shows correct scheduled date/time. Waited for first pester. Fired at 09:00. Snoozed task (10 mins) shows 09:10 (status: Snoozed). Adjusted the pester/snooze time (1min/3min). Hit apply settings. Status stays snoozed. Next pester time is set for original snooze time still (09:10). Functionally it works as it should, but it displays the time weird on the home screen. It will then pester me at the initial snooze time and then again at the updated pester time.
  - 🐛 Another bug. When a task is snoozed it will update the 'Next ' time to show snoozed time + pester time on the home screen. Example. If a task has a pester time of 1 min and I snooze it for 10 min at 09:00. It will show the 'Next' text as 09:11, then 09:12, then 09:13. I confirmed it increments after each 'pester time' duration. Looks like it is only the text though. The actual timer begins after the snooze time like it should. This just might be the difference in 'schedule for' time vs 'next pester time' strings. It looks like we shouldnt change the 'next pester time' while the task is snoozed.
- [x] Swipe an active task right and choose Complete.
  - *Expect* that task to become Completed and send no more alerts; other active tasks should continue unchanged.
  - *User notes:* ✅ Works as expected
- [x] Swipe an active task left and choose Snooze.
  - *Expect* that task to become Snoozed and restart at `Pester 1/8` after its own snooze duration; other active tasks should continue unchanged.
  - *User notes:* ✅ Works as expected
- [x] Complete one created task from its notification action.
  - *Expect* the matching task to become Completed and its remaining notifications to disappear.
  - *User notes:* ✅ Works as expected
- [x] Snooze another created task from its notification action.
  - *Expect* the matching task to become Snoozed and restart after its configured snooze duration.
  - *User notes:* ✅ Works as expected
- [x] Use Delete schedule from a task's detail screen.
  - *Expect* the task to remain in the inbox as Not scheduled, with no remaining notifications.
  - *User notes:* Task was deleted but it also removed it from the inbox. This is fine, but just different than what you expected.
- [x] Fully swipe a task row left and confirm permanent deletion, then delete a different task from its detail screen.
  - Expect the task and its delivered and pending notifications to disappear and remain absent after relaunch.
  - *User notes:* ✅ Works as expected, but it looks weird because the task row disappears and then re-appears when the confirmation box comes up. Not sure if this is just normal iOS behavior
- [x] Verify the empty state after permanently deleting every task, then create a new task from it.
  - *User notes:* ✅ Works as expected
- [x] Check the inbox, editor, and detail screen in light and dark appearance and with larger Dynamic Type.
  - Expect the build number to remain centered at the bottom of the inbox without a list-row background in both appearances.
  - *User notes:* ✅ Works as expected

The app currently schedules eight separate notification requests for every active or upcoming task. iOS notification scheduling limits still need physical-device characterization, so test many simultaneous tasks separately rather than treating this milestone as proof of unlimited scheduling capacity.

## v0.3.1 task list and detail

- ✅ Confirm the home screen shows Reminder A and Reminder B as tappable rows.
- ✅ Confirm each row shows its state and, when scheduled, its next pester date/time.
- ✅ Tap each task and confirm the detail screen shows title, state, pester count, next pester, schedule, durations, actions, status, task ID, and interaction log.
- ✅ Schedule or reschedule a task from its detail screen, then return to the list.
  - Expect the row to update without restarting the app.
- ✅ Start, snooze, complete, and delete schedules from the detail screen.
  - Expect the task state and row summary to match each action.
- ✅ Upgrade with an existing `0.3.0-0004` schedule still pending.
  - Expect the existing schedule, settings, actions, and logs to remain usable.
- ✅ Complete and snooze from a notification created by `0.3.1-0005`.
  - Expect the action to find the correct UUID-backed task and preserve the other task.
- ✅ Check the list and detail screens in light and dark appearance.
- ✅ Increase Dynamic Type and confirm task rows, labels, dates, buttons, and logs remain readable without horizontal clipping.

## v0.3.0 future scheduling

- ✅ Schedule Reminder A several minutes in the future.
  - Expect its exact future date and time to appear as Upcoming.
  - Expect no A notification before that time.
  - Expect `Pester 1/8` at the scheduled time, followed by alerts at the selected pester duration.
- ✅ Close Pester, reopen it before A is due, and close it again.
  - Expect the same scheduled time to remain visible and no early alert.
- ✅ Force-quit Pester before A is due.
  - Expect the scheduled notification to arrive without reopening the app.
- ✅ Restart the iPhone before A is due.
  - Expect the schedule and selected time to survive and the notification to arrive.
- ✅ Reschedule A to a different future time.
  - Expect only the new A schedule to fire; no alert should arrive at the old time.
  - Expect Reminder B to remain unchanged.
- ✅ Change A's durations while it is upcoming.
  - Expect A to retain its chosen first-fire time and use the new pester duration after that.
- ✅ Snooze A before its scheduled time.
  - Expect the original future schedule to be replaced by a snooze starting from now.
- ✅ Complete A before its scheduled time.
  - Expect no A alerts and a Completed state.
- ✅ Schedule A again, then use Delete schedule before it is due.
  - Expect no A alerts and a Not started state.
- ✅ Schedule A and B for separate future times, then edit or delete A.
  - Expect B's date, pending count, and notifications to remain unchanged.
- ✅ Keep Pester open when a future schedule becomes due.
  - Expect its banner and sound to be suppressed while the remaining batch stays active.

## Basic scheduling

- ✅ Start Reminder A.
  - Expect `Reminder A · Pester 1/8` after its configured pester duration.
- ✅ Let A reach `Pester 2/8` and `Pester 3/8`.
- ✅ Start Reminder B while A is active.
  - Expect B to begin on its independent schedule.
- ✅ Confirm A and B appear as separate notifications on the phone and third-party smartwatch.
- ✅ Kill Pester from the app switcher.
  - Expect scheduled notifications to continue.

## Settings

- ✅ Change A's pester duration before starting it.
  - Expect the setting to survive closing and reopening Pester.
- ✅ Change A's snooze duration.
- ✅ Start A and confirm the next alert follows the configured pester duration.
- ✅ Change A's settings while A is active.
  - Expect A's schedule to restart using the new values.
  - Expect B's schedule to remain unchanged.
- ✅ Set A and B to different pester durations and confirm their counters progress independently.

## Snooze

- ✅ Let A reach a visible count, then snooze it from the notification.
  - Expect no A alert during the snooze duration.
  - Expect A to restart at `Pester 1/8` afterward.
- ✅ Snooze A from inside the app and repeat the same test.
- ✅ Snooze A while B is active.
  - Expect B's pending notifications and pester count to continue unchanged.
  - Earlier build reset/cleared B; regression test the revised task isolation.
- ✅ Let B exhaust `8/8`, then snooze A from its notification.
  - Expect overdue B to restart at `Pester 1/8`.
  - Reported failure before the overdue-only cross-task reset was implemented: B did not restart.

## Complete

- ✅ Let A reach a visible count, then complete it from the notification.
  - Expect no further A alerts.
- ✅ Reopen Pester and confirm A has no pending notifications.
- ✅ Complete A while B is active.
  - Expect B's pending notifications and pester count to continue unchanged.
  - Earlier build reset/cleared B; regression test the revised task isolation.
- ✅ Let B exhaust `8/8`, then complete A from its notification.
  - Expect overdue B to restart at `Pester 1/8`.
- ✅ Start a newer batch, then use Complete on an old notification.
  - Expect the old action not to affect the newer schedule.
  - Testing: old notifications dissappear when I complete the task in the app

## App-open reset behavior

These are intended product behaviors; failures should become implementation tasks.

- ✅ Confirm the app-open lifecycle event is logged.
  - Check A's interaction log for `App opened — reset check`.
- ✅ Let A become active at `Pester 2/8`, then open Pester and leave again.
  - Intended: A remains active and continues with `Pester 3/8`; opening the app does not reset it.
  - Testing 1: Continued the count. I let the alert get to 2/20 then unlocked the phone and opened the app for a few seconds. Closed the app and locked the phone. The next alert showed 3/20.
  - Testing 2: The superseded active-reset design worked correctly before this behavior was intentionally removed.
- ✅ Let a task exhaust all 8 alerts without completing it.
  - Intended: it becomes overdue.
- ✅ Open Pester after it becomes overdue.
  - Intended: it resets and begins again at `Pester 1/8`.
- ✅ Snooze a task, then open Pester before the snooze ends.
  - Intended: it remains upcoming and does not start pestering early.
- ✅ Complete a task, reopen Pester, and wait.
  - Intended: it remains completed and sends no alerts.

## Foreground behavior

- ✅ Keep Pester open when an alert is due.
  - Expect no banner or sound; an active task retains its remaining pending alerts without resetting.
  - Earlier build: banner and sound appeared before foreground suppression was implemented.
- ✅ Open Pester, then switch to another app.
  - Record when the next notification appears.
- ✅ Lock the phone while Pester is open.
  - Record whether the schedule starts immediately or follows the configured pester duration.

## Interaction logging

- ✅ Tap a notification to open Pester.
  - Check for an “Opened app” entry in the interaction log.
- ✅ Use Complete and Snooze from the expanded notification.
  - Check that each action is logged.
- ✅ Swipe left and tap Clear.
  - Check whether a dismissal entry appears.
  - Result: no dismissal callback was observed; clearing an alert remains separate from Complete and Snooze.
- ✅ View or read a notification without acting.
  - Confirm that no read event is claimed.

## Results log

| Date | Build | Test or issue | Result | Follow-up |
| --- | --- | --- | --- | --- |
| 2026-09-10 | v0.1.0 | Repeated notifications | Passed on physical iPhone | — |
| 2026-09-10 | v0.1.0 | Third-party smartwatch alerts with identical text | Passed | Watch protocol remains unknown |
| 2026-09-10 | v0.1.0 | Snooze and Complete | Passed | — |
| 2026-09-10 | v0.1.0 | Notifications after killing app | Passed | — |
| 2026-09-10 | v0.2.0 | Two independent schedules | Passed by user | Add detailed counter/reset results |
| 2026-09-10 | 0.3.0-0004 | Future scheduling | Passed on physical iPhone | — |
| 2026-09-10 | 0.3.1-0005 | Task list and detail | Passed on physical iPhone | — |
| 2026-09-11 | 0.4.0-0008 | First New Task presentation | Paused for several seconds with iOS gesture/text-input service timeouts | Repeat attached and unattached to Xcode before changing app code |
| 2026-09-11 | 0.4.1-0010 | Snoozed and active next-pester display | Passed on physical iPhone; times update correctly and scheduling behavior remains correct | — |
| 2026-09-11 | 0.4.2-0011 | Swipe Delete confirmation | Middle-row deletion caused an optimistic row removal and list redraw before confirmation; the last row hid the effect because nothing followed it | Remove the destructive swipe role while retaining red styling and confirmed deletion |
| 2026-09-11 | 0.4.2-0014 | Task deletion controls | Passed on physical iPhone; confirmation no longer redraws the list and the selected-row highlight is clear | — |
| 2026-09-11 | 0.5.0-0018 | Inbox grouping and next-pester ordering | Passed on physical iPhone; section grouping, ordering, and completed-task separation work as expected | — |
| 2026-09-11 | 0.6.1-0026 | Task-details visual review | Unresolved; the prototype does not look right and feels too context-heavy | Redesign the composition collaboratively before physical-device testing |
| 2026-09-11 | 0.6.1-0027 | Icon-first task-details prototype | Simulator build and visual check passed; action bar, title/due hierarchy, and duration menus are functional | Keep the design unaccepted until the user reviews its labels, value treatment, and overall feel |
| 2026-09-11 | 0.6.1-0028 | Task-details spacing and surface refinement | Build-valid; simulator review pending | Keep the duration row unchanged while reviewing the shorter sheet, icon-only actions, title border, and gray due surface |
| 2026-09-11 | 0.6.1-0029 | Stacked title and due card | Build-valid; simulator review pending | Compare the stacked title/due treatment against the supplied reference; leave duration unchanged |
| 2026-09-11 | 0.6.1-0030 | Action-button affordance | Build-valid; simulator review pending | Review the subtle neutral circular borders around the colored action icons |
| 2026-09-11 | 0.6.1-0031 | Action-control size | Build-valid; simulator review pending | Review the 48-point controls against the prior 44-point treatment |
| 2026-09-11 | 0.6.1-0032 | Action and title hit areas | Build-valid; simulator review pending | Verify taps in visual spacing do not trigger action controls or title editing |
| 2026-09-12 | 0.6.2-0041 | Title-card hit area | Build-valid; simulator review pending | Verify the full title-card surface opens title editing without affecting the due-date control |
| 2026-09-11 | 0.6.1-0033 | Action-control size refinement | Build-valid; simulator review pending | Review the 53-point controls against the prior 48-point treatment |
| 2026-09-11 | 0.6.1-0034 | Title display treatment | Build-valid; simulator review pending | Review the centered all-caps rounded title and decide the due-surface hierarchy separately |
| 2026-09-11 | 0.6.1-0035 | Task-title treatment correction | Build-valid; simulator review pending | Reverted `0034`; the requested title/description polish applies to the inbox |
| 2026-09-11 | 0.6.1-0036 | Inbox title and description experiment | Build-valid; simulator review pending | Review the centered all-caps rounded title and muted centered description surface |
| 2026-09-11 | 0.6.1-0037 | Inbox headspace reduction | Build-valid; simulator review pending | Review the navigation-bar title placement and reduced top spacing |
| 2026-09-12 | 0.6.1-0044 | Consolidated development build | Simulator build passed; physical-iPhone testing pending | Validate task-row/title-card hit areas, completed-task controls, and notification hierarchy together |
| 2026-09-12 | 0.6.1-0045 | Task-row hit-area follow-up | Simulator build passed; physical-iPhone testing pending | Verify blank space across each inbox row opens that task |
| 2026-09-12 | 0.6.1-0045 | Task-row hit area | Passed on physical iPhone | — |
