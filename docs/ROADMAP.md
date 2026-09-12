# Pester roadmap

Pester is a focused reminder app built around one behavior: a task keeps pestering until it is completed or snoozed. The roadmap below reflects the current implementation path and keeps the first release local and small.

## ✅ v0.1.0 — notification foundation

✅ Initial SwiftUI app setup.
✅ Build and install Pester on the physical iPhone.
✅ Schedule and verify a single notification.
✅ Add the first pestering notification behavior.
✅ Complete or snooze a reminder from the notification context menu.
✅ Perform basic stability testing on the phone.

## ✅ v0.2.0 — configurable pestering

✅ Customizable snooze duration (1–60 minutes).
✅ Customizable pestering interval (1–60 minutes).
✅ Two independent reminders with different pestering intervals.
✅ Changing a duration updates the outstanding notification schedule correctly.
✅ Opening the app resets overdue tasks only; active pester counts continue unchanged.
✅ Completing or snoozing one task resets other overdue tasks while leaving active, upcoming, and completed tasks unchanged.
✅ Completion and snooze behavior tested across both schedules.
✅ Build identification added: `0.2.0-0003` (release version plus incrementing build number).

## v0.3.0 — scheduled future tasks

- ✅ Add the ability to schedule a task for a future date and time.
- ✅ Show the scheduled date and time clearly in the task view.
- ✅ Ensure a future task does not pester before its scheduled time.
- ✅ Persist future task schedules across app launches and device restarts.
- ✅ Allow a future task to be edited, completed, snoozed, or deleted before it becomes due.
- ✅ Verify future scheduling on the physical iPhone.

Completed and verified on the physical iPhone in build `0.3.0-0004`.

## v0.3.1 — task detail cleanup

- ✅ Present reminders as tappable task rows.
- ✅ Move task properties, scheduling controls, actions, and diagnostics into a task detail screen.
- ✅ Give each task a stable UUID and a user-facing task state.
- ✅ Preserve existing schedules and settings while moving from the test-reminder model to `PesterTask`.
- ✅ Verify navigation, state updates, notification actions, Dynamic Type, and light/dark appearance on the physical iPhone.

Completed and verified on the physical iPhone in build `0.3.1-0005`.

## ✅ v0.4.0 — task inbox

- ✅ Introduce the inbox.
- ✅ Create tasks with a title and due date/time.
- ✅ Give each task its own snooze duration and pester duration.
- ✅ Persist tasks locally across app launches and device restarts.
- ✅ Edit and delete tasks.
- ✅ Complete or snooze tasks from the inbox and from notification actions.

Completed across builds `0.4.0-0008` through `0.4.2-0014` and verified on the physical iPhone.

## ✅ v0.4.1 — snooze display correction

- ✅ Show a stable Snoozed until time while a task remains snoozed.
- ✅ Continue showing the moving next-pester time once the task is active.
- ⏭️ Defer title-only edit rescheduling cleanup to the v0.6.0 UI cleanup and polish milestone.

Implemented and verified on the physical iPhone in build `0.4.1-0010`.

## ✅ v0.4.2 — task deletion clarity

- ✅ Use Delete task as the single removal action; do not expose a separate schedule-cancellation action.
- ✅ Require an explicit Delete tap and confirmation after swiping a task row.
- ✅ Prevent SwiftUI's destructive swipe role from optimistically removing and redrawing the row before confirmation.
- ✅ Highlight the selected row while the native swipe confirmation is visible.

Implemented and verified on the physical iPhone in build `0.4.2-0014`.

## ✅ v0.5.0 — next-pester ordering

- ✅ Track each task’s next pester time.
- ✅ Order the inbox by pestering tasks (active and overdue), snoozed tasks, today tasks (upcoming and due today), then future tasks (upcoming and due after today).
	- ✅ Create sections on the home screen for these groups, plus Unscheduled tasks.
	- ✅ Add a color indicator next to each (pestering=red; snoozed=purple; today=green; future and unscheduled=gray).
- ✅ Move completed tasks out of the inbox into a dedicated Completed screen.
- ✅ Show the next pester time clearly for each task.
- ✅ Recalculate ordering after completion, snooze, editing, and a delivered notification.
- ✅ Prevent stale or duplicate notification schedules when task timing changes.

Implemented and verified on the physical iPhone in build `0.5.0-0018`. Active and overdue tasks appear under Pestering, Today contains only upcoming tasks due today, and completed tasks appear on a dedicated screen reached from the bottom of the inbox. Store refreshes are coalesced so section changes do not repeatedly update navigation within one display frame.

## v0.6.0 — finalized inbox grouping

- 🚧 Finalize the inbox groups:
	- 🚧 Pestering contains Overdue, Active, and Snoozed tasks, sorted by state priority, next pester time, then oldest creation time.
	- 🚧 Upcoming contains tasks due today and in the future, sorted by next pester time, then oldest creation time.
	- 🚧 Use a green clock for tasks due today and the existing blue clock for later tasks.
	- 🚧 Remove the separate Snoozed, Today, Future, and Unscheduled sections.
- 🚧 Require every task to have a scheduled date and time; an unscheduled reminder is not part of the product model.

Implemented in build `0.6.0-0020` and validated in the simulator; broader physical-iPhone testing is pending.

## v0.6.1 — task detail redesign

- Collaboratively redesign the task detail page and its information hierarchy before implementation.
- Clarify the relationship between task properties, schedule, actions, status, and diagnostic information.
- Keep common task actions easy to reach without overwhelming the primary task information.
- Polish the inbox, task creation, editing, and notification flows.
- Prevent title-only edits from changing a task's lifecycle or notification timing.

## v0.6.x — remaining polish and stability

- Add colors to overdue, upcoming, active
- Improve empty, permission-denied, and scheduling-error states.
- Verify Dynamic Type, accessibility labels, and common screen sizes.
- Test repeated launches, edits, completion, snoozing, and notification actions.
- Test locked, backgrounded, offline, force-quit, and reboot scenarios on the physical iPhone.
- Resolve crashes, duplicate alerts, stale alerts, and persistence errors.

## v1.0.0 — initial release

Ship the first complete local version of Pester:

- Task inbox.
- Task creation and editing.
- Custom snooze and pester durations.
- Next-pester ordering.
- Repeated pestering notifications.
- Complete and snooze actions from the app and notification context menu.
- Durable local task state.
- Physical-iPhone validation of the core flow.

## v1.1.0 — external task creation experiment

Begin testing external control after the local app is stable:

- Define the first API/MCP task operations.
- Test creating a task from outside the iPhone app.
- Investigate how the phone learns about externally created tasks while the app is closed.
- Keep this experimental until synchronization and notification delivery behavior are understood.

## v2.0.0 — API release

Release the external API and MCP integration as a deliberate second major version:

- Documented API for creating, listing, updating, completing, snoozing, and deleting tasks.
- Authentication and secure server exposure.
- Shared task logic between the app and API.
- Synchronization between server state and local iPhone state.
- Clear handling for tasks created while the app is closed or offline.
- MCP tools for AI agents, subject to the reliability demonstrated in v1.1.0.

The API and MCP work should build on the proven local task lifecycle rather than expanding the 1.0 release prematurely.
