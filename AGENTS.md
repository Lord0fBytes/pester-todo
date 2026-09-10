# Pester

Pester is a focused native iPhone app: persistent reminders that keep pestering the user until explicitly completed or snoozed. Think of it as a tiny reminder daemon for humans with an excellent API for AI agents.

## Product scope

- Keep v1 deliberately small: reminder list, create/edit reminders, title, due date/time, configurable nag interval, complete, snooze, and notification actions.
- Support local persistence, backend synchronization, a real API, and MCP integration as the product develops.
- Do not expand into a general productivity system or Todoist replacement.
- AI agents, especially ChatGPT, should be able to create and manage reminders directly. URL schemes and Apple Shortcuts must not be the primary integration mechanism.
- Natural-language parsing can live in the AI layer; it is not required in the initial iPhone app.

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

- Added a dependency-free SwiftUI notification proof of concept in `Pester.xcodeproj` (iPhone, iOS 16+).
- The current experiment schedules a finite batch of 20 numbered one-shot notifications, one minute apart. Snooze replaces the batch starting three minutes later, with “After snooze” titles and numbering restarting at 1. Complete removes pending/delivered test alerts, including legacy requests. This is not indefinite pestering.
- Notification categories report Complete, Snooze, app-open taps, and explicit dismissal callbacks. A capped local diagnostic log persists these events; seeing/reading and unattended background delivery are not inferred from callbacks. Actions are serialized and old-batch actions are rejected.
- Signing uses Xcode automatic signing; select the user's Personal Team and an available bundle identifier before installing.
- Xcode is installed. The user confirmed installation and delivery of the original ten-second notification on their locked physical iPhone. The user also reported five repeat cycles, resumed delivery after the original one-minute snooze, and completion followed by several minutes of waiting. One visible notification and inconsistent third-party smartwatch alerts were observed with the repeating request. The user subsequently confirmed individual smartwatch alerts and successful three-minute snooze with the numbered batch. Swipe-dismiss logging remains unconfirmed/not observed; comprehensive visual and lifecycle testing remains outstanding.
- This remains a single-reminder notification experiment. A local diagnostic log and batch-generation token use UserDefaults; reminder storage, arbitrary due dates, backend, and MCP are not implemented.

- `docs/ROADMAP.md` is the user-authored milestone plan: local notification foundation through local v1.0, then external API/MCP experiments and release.

## Prior conversation

- Previous conversation: https://chatgpt.com/share/6aa2b94c-3ddc-83e8-8fd6-d1d06701a72b
- This file summarizes the project context supplied by the user; the linked conversation has not been independently reviewed.
