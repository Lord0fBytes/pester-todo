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
- **Upcoming:** a future-scheduled or snoozed task that is not currently pestering.
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
- v0.1.0 and v0.2.0 are committed and merged into `main`. The current development branch is `0.3.0`.
- When the app opens, only overdue tasks reset. Active tasks keep their current pester count and pending notifications. Upcoming future-scheduled or snoozed tasks retain their upcoming state and schedule. Completed tasks remain completed.
- The app-open lifecycle event is confirmed in testing: each reminder log records `App opened — reset check`.
- Completing or snoozing a notification resets other overdue tasks only. Active and upcoming tasks keep their pending notifications and counts; completed tasks remain completed. The triggering task follows its explicit Complete or Snooze transition.
- The pester counter is the number of notifications allowed before a task becomes overdue; it is separate from pester duration and snooze duration.

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

## Repository setup status

- Working branch: `0.3.0`; two independent test reminders A/B, default pester intervals 1/2 minutes, default snooze 3 minutes.
- Each reminder has saved pester/snooze settings (1–60 minutes), a separate 8-request batch, generation token, and local diagnostic log. Notification text includes the pester count for debugging.
- Debug notification text currently includes the pester count, such as `Pester 1/8`, so reset behavior can be observed on the phone and third-party smartwatch. This is temporary diagnostic presentation, not the intended final notification copy.
- Saving edited settings replaces only that reminder's pending batch if active, restarting its countdown. Inactive reminders save settings without starting. Complete/Snooze actions target one reminder via payload ID; stale batch actions are ignored.
- Opening the app preserves active schedules and resets only overdue tasks. A reset overdue task waits until the app enters the background before installing a fresh `1/8` batch. Upcoming snoozed schedules and completed tasks are preserved.
- Foreground alerts are suppressed without resetting active tasks. If the final scheduled alert is exhausted while Pester is visible, the now-overdue task resets and waits for the app to leave.
- Complete and Snooze operate on their associated task and reset any other overdue tasks. Other active, upcoming, and completed tasks and notifications remain unchanged.
- Launch removes obsolete v0.1 test requests. v0.2 schedules/settings survive app relaunch via iOS pending requests and UserDefaults. These are experiment settings, not the future task database.
- Build `0.3.0-0004` adds a future date/time picker, persisted first-fire time, per-reminder rescheduling, and schedule deletion. A future batch starts at the chosen time and uses the configured pester duration for its remaining alerts. Unsigned iPhone build passes; physical-device testing is pending.
- Notification categories request Complete, Snooze, app-open, and explicit-dismiss callbacks. Swipe-dismiss logging remains unconfirmed; no read receipt or unattended delivery callback is inferred.
- Signing uses Xcode automatic signing with the existing project team configuration.
- `docs/ROADMAP.md` is the user-authored milestone plan. v0.3.0 covers future scheduling; the inbox, backend/API, and MCP remain out of scope for this iteration.
- Build identification uses `MARKETING_VERSION` for the release (currently `0.3.0`) and numeric `CURRENT_PROJECT_VERSION` for installable builds (currently `4`). The app displays them as `0.3.0-0004`; increment the build number for each distinct installable code build. See `docs/BUILD.md`.

## v0.1.0 completion

- User closed v0.1.0 after confirming repeated third-party smartwatch alerts with identical title/body and a scheduled notification after killing the background app. This validates the observed tests, not unlimited delivery or all lifecycle cases.
- Same-text separate requests pass the unsigned iPhone build. Internal IDs appear only in diagnostic logs. Swipe-dismiss logging, reboot behavior, and full batch exhaustion remain unverified.
- The notification foundation is complete; further implementation follows `docs/ROADMAP.md`.

## Prior conversation

- Previous conversation: https://chatgpt.com/share/6aa2b94c-3ddc-83e8-8fd6-d1d06701a72b
- This file summarizes the project context supplied by the user; the linked conversation has not been independently reviewed.
