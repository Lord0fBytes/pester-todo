# Pester

Pester is a focused native iPhone app: persistent reminders that keep pestering the user until explicitly completed or snoozed. Think of it as a tiny reminder daemon for humans with an excellent API for AI agents.

## Product scope

- Keep v1 deliberately small: reminder list, create/edit reminders, title, due date/time, configurable nag interval, complete, snooze, and notification actions.
- Support local persistence, backend synchronization, a real API, and MCP integration as the product develops.
- Do not expand into a general productivity system or Todoist replacement.
- AI agents, especially ChatGPT, should be able to create and manage reminders directly. URL schemes and Apple Shortcuts must not be the primary integration mechanism.
- Natural-language parsing can live in the AI layer; it is not required in the initial iPhone app.

## Domain definitions

- **Pester duration:** the time between notifications while a task is pestering.
- **Snooze duration:** the time until the next set of pestering notifications begins.
- **Pester count:** the maximum number of notifications that can trigger before the task becomes overdue.
- **Overdue:** a task that has exhausted its pester count and has not been completed.
- **Active:** a task that is actively sending pestering notifications.
- **Upcoming:** a future-scheduled task that has not begun pestering.
- **Snoozed:** a task whose pestering cycle is paused until its fixed snooze deadline.
- **Completed:** a task that has been explicitly dismissed as complete.
- **Pestering:** the state in which one or more tasks are actively sending notifications.

## Confirmed decisions and observations

- The first physical-iPhone milestone passed: Pester installed from Xcode, requested notification permission, and delivered a local notification while the phone was locked.
- The v0.1.0 pestering experiment passed on the physical phone: repeated alerts continued after the app was killed, Snooze resumed pestering, and Complete stopped alerts after several minutes of observation.
- A finite batch of separately identified notifications with identical title/body also delivered individual alerts to the user's third-party smartwatch. Changing notification text is not required under that tested configuration.
- Third-party smartwatch forwarding is separate from Apple Watch routing. Apple documents ANCS, which exposes notification added, modified, and removed events to Bluetooth accessories; the particular watch's protocol has not been identified.
- Notification content is delivered by iOS; the app can receive callbacks for custom actions, opening a notification, and some explicit dismissals. It cannot infer that a person merely saw or read an alert, and a banner swipe/reveal is not guaranteed to produce a dismissal callback.
- Dismissal is not completion. Clearing an alert should not stop pestering; Complete and Snooze are the explicit lifecycle actions.
- Local notification delivery is best effort and platform-controlled. A successful schedule or pending-request snapshot does not prove presentation, sound, smartwatch forwarding, or exact timing.
- v0.1.0 through v0.5.0 are complete and merged into `main`. Build `0.5.0-0018` is the current physically tested release.
- When the app opens, only overdue tasks reset. Active tasks keep their current pester count and pending notifications. Upcoming future-scheduled or snoozed tasks retain their upcoming state and schedule. Completed tasks remain completed.
- The app-open lifecycle event is confirmed in testing: each reminder log records `App opened — reset check`.
- Completing or snoozing a notification resets other overdue tasks only. Active and upcoming tasks keep their pending notifications and counts; completed tasks remain completed. The triggering task follows its explicit Complete or Snooze transition.
- The pester counter is the number of notifications allowed before a task becomes overdue; it is separate from pester duration and snooze duration.
- Every user-created task must have a scheduled date and time. An Unscheduled task or inbox group is not part of the product model. The existing `.notScheduled` case is an internal pre-v1 fallback to remove during v0.6 lifecycle cleanup; no data migration is needed because the user is the only tester and has no unscheduled tasks.

## First milestone

Before building a backend or substantial UI:

1. Verify Xcode is installed and configured.
2. Create a minimal SwiftUI app called Pester.
3. Build and install it on the user's physical iPhone.
4. Request notification permission and schedule one local notification.
5. Have the user confirm that it fires on the phone.

Then experiment with persistent notification behavior before committing to the broader architecture. Do not treat a successful build or simulator test as confirmation of delivery on the physical phone.

## Architecture direction — provisional

- iPhone: Swift, SwiftUI, UserNotifications, and local persistence via SwiftData or SQLite (undecided).
- Prefer local notification scheduling for repeated nags where iOS permits it; complete/snooze must cancel or update outstanding notifications.
- Backend: likely self-hosted, potentially TypeScript with PostgreSQL, REST API, MCP tools, and an APNs service. These are candidates, not finalized choices.
- API/MCP operations should include create, list, update, delete, complete, and snooze, sharing the same underlying reminder logic.
- Critical scenario: an AI creates a reminder while the iPhone app is closed. The phone must learn about it and deliver reminders. APNs-assisted sync is proposed, but its reliability and execution constraints still need validation.
- Do not assume a silent push will wake the app or that the app can indefinitely replenish local notifications in the background.

## Research before locking the architecture

Store project research in `research/`. Notification constraints, sources, and proposed device experiments live in `research/NOTIFY.md`; research findings do not imply implementation or physical-device validation.

Check current official documentation rather than relying on remembered platform behavior:

- Pending notification limits, repeating trigger restrictions/minimum intervals, batch scheduling, and replenishment.
- Notification actions, complete/snooze handling, background execution, reboot behavior, and APNs-to-local scheduling.
- Current ChatGPT support for custom/self-hosted MCP servers, authentication, tool invocation, and secure exposure.
- If investigating Due, distinguish observable behavior from guesses about its implementation.

## Development context

- The user is comfortable with programming, Docker, Linux, TypeScript, APIs, and PostgreSQL, but is new to native iOS development.
- Explain unfamiliar Apple concepts when relevant: signing, provisioning, bundle identifiers, entitlements, APNs, permissions, and background execution.
- The Mac Mini is the intended primary development/build machine; initial testing targets a physical iPhone.
- Keep Xcode and Apple tooling on the internal SSD. Projects, DerivedData, and archives may live on an external SSD. Avoid unsupported simulator-storage symlink workarounds and keep simulator runtimes minimal.
- App Store publication is not required initially. Developer Program enrollment, TestFlight, and distribution can be addressed when needed.

## Working approach

- Make small, verifiable changes and keep this file updated as decisions are confirmed.
- Clearly distinguish implemented behavior, proposed design, and platform assumptions awaiting validation.
- Do not build the full app/backend ahead of the notification proof of concept unless the user changes the scope.
- Format new `docs/TESTING.md` cases as a checkbox followed by italicized `Expect` and `User notes` entries. Preserve the user's notes verbatim when recording results, and leave unresolved observations open until they are discussed or reproduced.
- During the v0.6 UI work, collaborate on the overall look and future implications before implementing loosely formed ideas. Treat simulator prototypes as proposals until the user explicitly accepts their look and feel; record rejected iterations without promoting them to confirmed design.

## Repository setup status

- Build `0.6.0-0020` is the finalized-inbox-grouping checkpoint and awaits physical-iPhone testing. The task-details work continues on `feature/0.6.1-task-details`; build `0.6.1-0037` is a build-valid prototype.
- The v0.6 inbox has two task sections: Pestering contains Overdue, Active, and Snoozed; Upcoming contains future-scheduled tasks due today or later. Completed remains on its dedicated screen. The Pestering label is a presentation group and does not mean a Snoozed task is actively sending notifications.
- Pestering sorts first by state priority (Overdue, Active, Snoozed), then by the next pester or snooze deadline, then by creation time oldest first. Upcoming sorts by next pester time and then creation time oldest first.
- Upcoming rows due today use a green clock. Later Upcoming rows retain the blue clock. Their status and displayed date continue to communicate meaning without relying only on color.
- Inbox section headings use plain text without colored dots. The Completed navigation row uses a secondary gray checkmark so it does not compete visually with active task content.
- The confirmed task-details content direction is a top action bar (lifecycle actions when applicable, Delete, and Close), followed by title, due timestamp, pester duration, and snooze duration. Do not show next-pester time, lifecycle status, pester count, task ID, or interaction log in this surface. The exact visual composition remains undecided.
- Build `0.6.1-0026` experiments with a medium/large native sheet, Form-style cards, matching light bordered Complete/Snooze actions, focused title and due editors, and immediate duration-menu saves. The user rejected the current presentation as still not looking right and feeling too context-heavy. Do not treat its cards, spacing, action styling, or overall hierarchy as accepted visual design.
- Build `0.6.1-0027` replaces the normal inspector's Form-style cards with a compact custom sheet: evenly spaced circular Complete, Snooze, Delete, and Close controls; an editable large title with muted due timestamp; and bell/timer duration menus showing compact current values. This is a simulator-validated proposal, not an accepted design or a physical-device test candidate. The action labels and duration-value-only treatment remain open for review.
- Build `0.6.1-0028` refines that proposal with a shorter initial sheet, more space below the drag indicator, icon-only actions without colored fills, a lightly bordered title surface, and a muted gray due-date surface. The duration treatment is intentionally unchanged and remains open for redesign. This is still a simulator-validated proposal, not an accepted design or a physical-device test candidate.
- Build `0.6.1-0029` makes the title and due date one stacked task card, following the supplied visual reference: a clean title surface above a taller muted-gray due-date surface with one enclosing border. The duration treatment remains intentionally unchanged and open for redesign. This is still a simulator-validated proposal, not an accepted design or a physical-device test candidate.
- Build `0.6.1-0030` adds subtle neutral circular borders to the icon-only action controls so their tappable affordance is visible while the icons remain the only colored elements. This remains an unaccepted, simulator-validated proposal.
- Build `0.6.1-0031` increases the visible outlined action controls from 44 to 48 points (about 9%) while retaining their existing spacing and semantics. This remains an unaccepted, simulator-validated proposal.
- Build `0.6.1-0032` limits action hits to each visible 48-point circle and title editing to the padded title text, leaving the visual spacing and unused title-card surface noninteractive. This remains an unaccepted, simulator-validated proposal.
- Build `0.6.2-0041` supersedes the title-hit boundary from `0032`: the complete title-card surface is interactive so an accidental tap target does not confuse users. This remains an unaccepted, simulator-validated proposal.
- Build `0.6.1-0033` increases the visible outlined action controls from 48 to 53 points, another approximately 10% increase, while retaining exact visible hit areas. This remains an unaccepted, simulator-validated proposal.
- Build `0.6.1-0034` uses a centered all-caps rounded display treatment for the title while keeping its tap target limited to the title itself. The due-date surface remains open for a separate polish direction.
- Build `0.6.1-0035` reverts the `0034` task-title treatment: that change was based on a misunderstanding of feedback intended for the inbox title and description. The task-details title returns to its prior leading title style; inbox-title polish remains a separate open direction.
- Build `0.6.1-0036` applies that intended inbox-title experiment: a centered all-caps rounded Pester heading and a centered muted explanatory surface. This is a simulator-only visual proposal, not accepted design.
- Build `0.6.1-0037` moves the centered all-caps rounded inbox title into the navigation bar, removing excess list headspace while retaining the explanatory surface below it. This is a simulator-only visual proposal, not accepted design.
- Build `0.6.1-0044` is the consolidated development build: it combines the task-row hit target, title-card hit target, completed-task duration visibility, notification hierarchy, and time-picker roadmap work. Physical-iPhone testing remains pending.
- Build `0.6.1-0045` moves the task-row hit region into the button label itself and explicitly gives it the full row width, addressing physical testing that found the outer button modifier insufficient. Physical-iPhone verification passed.
- Build `0.6.1-0046` uses the native iOS time picker with five-minute increments for new tasks and both task-editing surfaces. A new task defaults to the next five-minute boundary. Simulator validation passed; physical-iPhone testing is pending.
- The current prototype's title-only save updates pending notification titles while preserving identifiers, fire times, pester count, and lifecycle. Its duration choices are 1, 2, 3, 4, 5, 10, 15, 20, 30, 45, and 60 minutes. These functional behaviors are implemented, but their presentation remains open with the rest of the task-details redesign.
- Current physically tested release: `0.5.0-0018`. v0.5.0 inbox grouping and next-pester ordering are complete and merged into `main`.
- The v0.5 inbox uses ordered, nonempty sections: Pestering, Snoozed, Today, Future, then Unscheduled. Pestering contains Active and Overdue tasks. Today contains only Upcoming tasks due today. Completed tasks are hidden from the inbox sections and available through a dedicated Completed screen at the bottom of the inbox.
- Sections sort by their relevant scheduled time, earliest first, with task title as a stable tie-breaker. Overdue tasks sort before Active tasks within Pestering. Headers use red for Pestering, purple for Snoozed, green for Today, and gray for Future and Unscheduled.
- `TaskStore` republishes task-level lifecycle changes so the parent inbox recomputes grouping and ordering after scheduling, snoozing, completion, overdue reset, and notification-status refreshes. Build `0.5.0-0016` coalesces those refreshes and uses one scene-phase task, preventing repeated NavigationStack updates within a single display frame.
- Build `0.4.0-0008` introduces a dynamic task inbox. Users can create tasks with a title, future due date/time, pester duration, and snooze duration; edit them; complete or snooze them with inbox swipe actions; and permanently delete them with a full trailing swipe or from the detail screen.
- The first physical-device opening of the New Task sheet in `0.4.0-0008` paused for several seconds while iOS logged gesture-gate, result-accumulator, and reporter-disconnection timeouts. A similar first-opening delay was reproduced in the iOS 26.5 simulator. The Add handler itself only changes sheet presentation state; repeat testing with and without Xcode attached is pending before attributing the delay to Pester code.
- Initial `0.4.0-0008` phone testing passed legacy-task migration, creation of multiple independent tasks, persistence across relaunch/force-quit/reboot, inbox Complete/Snooze gestures, notification Complete/Snooze actions, and light/dark appearance. Editing remains open: changing only a title unexpectedly rescheduled the task as Upcoming, and changing durations on a snoozed task produced unclear snoozed-state behavior that needs reproduction before implementation changes.
- The user chose to defer title-only edit rescheduling behavior until the v0.6.0 UI cleanup and polish milestone.
- Build `0.4.1-0010` displays notification times from their fixed absolute fire dates. Newly scheduled requests include that date in their payload, while older pending requests reconstruct it from the batch start and sequence number. A snoozed task displays its fixed deadline as `Snoozed until`; after it becomes active, the UI displays the next request's original scheduled time instead of recalculating a relative trigger from the current time. Applying duration changes while snoozed continues to preserve the original snooze deadline and applies the new pester interval afterward.
- The `0.4.1-0010` snooze-display correction passed physical-iPhone testing: displayed times advance correctly after the snooze deadline, and notification scheduling behavior remains correct.
- Physical-phone video of `0.4.2-0011` confirmed that a swipe button declared with SwiftUI's destructive role optimistically removes its row before the handler's confirmation dialog resolves. Rows below a middle task shift up and then redraw; the same behavior is visually hidden on the last row because no rows follow it.
- Build `0.4.2-0012` removes the destructive role from the swipe button while retaining its red tint, so the list should not redraw before confirmation. It also removes the separate Cancel notification schedule control by product decision; Delete task is the sole removal action and cancels all associated notifications.
- SwiftUI's native swipe actions close after their button is tapped and provide no supported keep-open control. Build `0.4.2-0014` keeps the short confirmation title and highlights the selected row behind the dialog so the deletion target remains clear without placing potentially long task text in the dialog.
- The `0.4.2-0014` deletion flow passed physical-iPhone testing. The row remains stable before confirmation, the selected-row highlight provides context, and confirmed deletion removes the task and its notifications.
- Delete Schedule was observed to remove a task from the inbox even though the test expected it to retain a Not scheduled task; this needs reproduction. A full-swipe deletion passed, but the row temporarily disappeared and returned while its confirmation dialog was shown.
- Tasks persist as a Codable JSON collection in UserDefaults for this milestone. On the first 0.4 launch, the store migrates the legacy Reminder A/B controllers into UUID-backed records while retaining their existing notification keys, settings, schedules, and logs.
- `TaskStore` owns the task collection and resolves notification actions to dynamically created tasks. `PesterTask` remains the task domain boundary and owns each task's notification behavior.
- Each task has saved pester/snooze settings (1–60 minutes), a separate 8-request batch, generation token, and local diagnostic log. Pester counts remain available in internal diagnostics.
- Notification presentation uses `Pester` as the notification title and the task name as its body. The pester count and snooze guidance are not user-facing notification text.
- Saving edited settings replaces only that reminder's pending batch if active, restarting its countdown. Inactive reminders save settings without starting. Complete/Snooze actions target one reminder via payload ID; stale batch actions are ignored.
- Opening the app preserves active schedules and resets only overdue tasks. A reset overdue task waits until the app enters the background before installing a fresh `1/8` batch. Upcoming snoozed schedules and completed tasks are preserved.
- Foreground alerts are suppressed without resetting active tasks. If the final scheduled alert is exhausted while Pester is visible, the now-overdue task resets and waits for the app to leave.
- Complete and Snooze operate on their associated task and reset any other overdue tasks. Other active, upcoming, and completed tasks and notifications remain unchanged.
- Launch removes obsolete v0.1 test requests. Existing v0.2/v0.3 schedules and settings survive the v0.4 migration through the retained per-task notification keys and UserDefaults state.
- Build `0.3.0-0004` added future date/time scheduling, persisted first-fire times, per-reminder rescheduling, and schedule deletion. Its future scheduling and lifecycle behavior passed physical-iPhone testing.
- Build `0.3.1-0005` promotes each reminder controller to a UUID-backed `PesterTask`. The root screen presents tappable task rows with state and next-pester summaries; each detail screen contains the task properties, schedule, durations, actions, status, and diagnostics. Existing storage keys and legacy notification payload IDs remain supported so v0.3.0 schedules survive the upgrade. The UI and notification regressions passed physical-iPhone testing.
- Notification requests remain an internal scheduling detail; a separately persisted `NotificationSchedule` entity is deferred until later storage or synchronization requirements justify it.
- The intended public task states are Upcoming, Active, Snoozed, Overdue, and Completed. State rows pair text with SF Symbols so meaning does not depend on color alone.
- The accepted navigation pattern is a compact task list with state and next-pester summaries, followed by a native detail screen for task properties and actions.
- Notification categories request Complete, Snooze, app-open, and explicit-dismiss callbacks. Swipe-dismiss logging remains unconfirmed; no read receipt or unattended delivery callback is inferred.
- Signing uses Xcode automatic signing with the existing project team configuration.
- `docs/ROADMAP.md` is the user-authored milestone plan. v0.5.0 is complete and verified on the physical iPhone.
- Build identification uses `MARKETING_VERSION` for the release (currently `0.6.1`) and numeric `CURRENT_PROJECT_VERSION` for installable builds (currently `46`). The app displays them as `0.6.1-0046`; increment the build number for each distinct installable code build. See `docs/BUILD.md`.

## v0.1.0 completion

- User closed v0.1.0 after confirming repeated third-party smartwatch alerts with identical title/body and a scheduled notification after killing the background app. This validates the observed tests, not unlimited delivery or all lifecycle cases.
- Same-text separate requests pass the unsigned iPhone build. Internal IDs appear only in diagnostic logs. Swipe-dismiss logging, reboot behavior, and full batch exhaustion remain unverified.
- The notification foundation is complete; further implementation follows `docs/ROADMAP.md`.

## Prior conversation

- Previous conversation: https://chatgpt.com/share/6aa2b94c-3ddc-83e8-8fd6-d1d06701a72b
- This file summarizes the project context supplied by the user; the linked conversation has not been independently reviewed.
