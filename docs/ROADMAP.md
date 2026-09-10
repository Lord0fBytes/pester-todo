# Pester roadmap

Pester is a focused reminder app built around one behavior: a task keeps pestering until it is completed or snoozed. The roadmap below reflects the current implementation path and keeps the first release local and small.

## ✅ v0.1.0 — notification foundation

✅ Initial SwiftUI app setup.
✅ Build and install Pester on the physical iPhone.
✅ Schedule and verify a single notification.
✅ Add the first pestering notification behavior.
✅ Complete or snooze a reminder from the notification context menu.
✅ Perform basic stability testing on the phone.

## v0.2.0 — configurable pestering

- Add customizable snooze duration.
- Add customizable pestering duration.
- Support two notifications with different pestering durations.
- Verify that changing a duration updates the outstanding notification schedule correctly.
- Opening the app resets all the pester counters even if no changes were made
- Test completion and snooze behavior across both schedules.

## v0.3.0 — scheduled future tasks

- Add the ability to schedule a task for a future date and time.
- Show the scheduled date and time clearly in the task view.
- Ensure a future task does not pester before its scheduled time.
- Persist future task schedules across app launches and device restarts.
- Allow a future task to be edited, completed, snoozed, or deleted before it becomes due.
- Verify future scheduling on the physical iPhone.

## v0.4.0 — task inbox

- Introduce the inbox.
- Create tasks with a title and due date/time.
- Give each task its own snooze duration and pester duration.
- Persist tasks locally across app launches and device restarts.
- Edit and delete tasks.
- Complete or snooze tasks from the inbox and from notification actions.

## v0.5.0 — next-pester ordering

- Track each task’s next pester time.
- Order the inbox by overdue tasks, next-up tasks, then future tasks.
- Show the next pester time clearly for each task.
- Recalculate ordering after completion, snooze, editing, and a delivered notification.
- Prevent stale or duplicate notification schedules when task timing changes.

## v0.6.0 — polish and stability

- Polish the inbox, task creation, editing, and notification flows.
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
