# Pester testing

This is the physical-device test checklist for the current `0.2.0` work. Update the checkboxes and results as each feature or bug is tested. Record the device model, iOS version, app build, notification settings, and smartwatch state when a result is surprising.

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
- [ ] Snooze A while B is active.
  - Expect B's pending notifications and pester count to continue unchanged.
  - Earlier build reset/cleared B; regression test the revised task isolation.
- [ ] Let B exhaust `8/8`, then snooze A from its notification.
  - Expect overdue B to restart at `Pester 1/8`.
  - Reported failure before the overdue-only cross-task reset was implemented: B did not restart.

## Complete

- ✅ Let A reach a visible count, then complete it from the notification.
  - Expect no further A alerts.
- ✅ Reopen Pester and confirm A has no pending notifications.
- [ ] Complete A while B is active.
  - Expect B's pending notifications and pester count to continue unchanged.
  - Earlier build reset/cleared B; regression test the revised task isolation.
- [ ] Let B exhaust `8/8`, then complete A from its notification.
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
- [ ] Snooze a task, then open Pester before the snooze ends.
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
- [ ] Swipe left and tap Clear.
  - Check whether a dismissal entry appears.
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
