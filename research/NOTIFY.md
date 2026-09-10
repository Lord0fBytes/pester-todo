# iOS notification reliability for Pester

Researched: 2026-09-10. Sources: Apple documentation and Apple engineering presentations. These are research findings and proposed experiments, not tested device behavior or a finalized architecture.

## What “consistent” needs to mean

**Main finding:** Apple attempts timely local and remote notification delivery but explicitly does not guarantee it. Pester can improve resilience and expose its current coverage; it cannot promise unconditional exact-time alerts or sound. [User Notifications](https://developer.apple.com/documentation/usernotifications)

Track these separately: the reminder was saved; the phone learned about it; iOS accepted its notification request; an alert appeared; a sound played; the user completed or snoozed it. Success at an earlier step does not prove a later step.

The user confirmed that the original ten-second local notification arrived on their locked physical iPhone. The next implementation adds a 60-second repeating test, foreground presentation, Complete, and Snooze 1 minute (resetting the same repeating interval). Repeating delivery and actions remain unverified on the physical phone; there is no reminder database, sync, or APNs.

## Local delivery and capacity

**Documented:** iOS handles scheduled local notifications when the app is backgrounded or not running. Foreground notifications go to the app for handling; presenting a banner or sound there needs delegate handling. This makes an installed local schedule a useful offline foundation. It does not establish reboot, pre-first-unlock, powered-off catch-up, or exact-second guarantees. [Scheduling local notifications](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)

**Historical documentation:** The familiar **64 pending notifications** limit is explicit for deprecated `UILocalNotification`: earliest 64 retained, with an automatically repeating notification counting as one. This research did not find an equivalent numeric guarantee for current `UNUserNotificationCenter`. Treat 64 as a conservative provisional budget, and verify counting, overflow, and retention on supported OS versions. Do not present the historical rule as a confirmed modern contract. [Deprecated UILocalNotification](https://developer.apple.com/documentation/uikit/uilocalnotification)

**Budget illustration, not a platform guarantee:** With an assumed 64 slots and four reserved, 60 five-minute alerts cover about five hours for one reminder; dividing those slots among five reminders gives each about one hour. Finite batches therefore need an explicit coverage horizon. Repeats may save slots, but only where their scheduling semantics fit.

## Scheduling trap: due date versus nag interval

**Documented:** `UNTimeIntervalNotificationTrigger` starts its interval from the current time. Repetition uses that same interval, which must be at least 60 seconds. A repeating request continues until explicitly removed. [Time interval initializer](https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger/init(timeinterval:repeats:))

**Inference:** “Due tomorrow at 15:00, then every five minutes” cannot be represented by one such trigger created today. Using five minutes starts too early; using the time until tomorrow repeats at the wrong cadence. A calendar trigger matches date components rather than expressing a separate start date plus interval. [Calendar triggers](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger)

**Proposal:** Test a finite batch of individual future alerts for exact due-time cadence, and test repeating triggers separately for reminders that are already nagging. Neither proves unlimited unattended future-date nagging. Any design that changes the schedule at the due date needs an actual execution opportunity; the system displaying a local notification is not itself a background scheduling callback.

Apple documents foreground delivery and user-action handling as distinct callbacks. Do not assume an untouched background local alert launches Pester to schedule its successor. [Handling notifications and actions](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions)

## Whether the person sees or hears it

**Documented:** Authorization and individual notification settings can change. Check them again rather than trusting an old permission result. Provisional authorization delivers quietly in notification history, without banner, sound, or Lock Screen presentation; repeated authorization requests do not repeatedly display the initial prompt. [Asking permission](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)

| Mechanism | Capability and limit |
| --- | --- |
| Ordinary notification | Presentation depends on permission, alert/sound settings, Focus, and Scheduled Summary. |
| Time Sensitive | Can bypass Focus and Summary when allowed; users can disable this. Does not bypass Silent mode. Use for information requiring immediate attention. |
| Critical alert | Can override Silent mode and interruption controls, but requires Apple's approved entitlement and user authorization. Do not assume ordinary reminders qualify. |

Sources: [Time Sensitive interruption level](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/timesensitive), [Managing notifications](https://developer.apple.com/design/human-interface-guidelines/managing-notifications).

**Proposal:** Eventually expose notification permission, sound/alert settings, installed schedule coverage, and last phone synchronization separately. “Saved” should not imply “installed on your phone.”

## Complete and snooze

**Documented:** A notification action can launch the app in the background and invoke its response handler without opening the UI. Register notification categories at launch, identify the reminder in the payload, handle the action, and call the completion handler. [Handling notifications and actions](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions)

**Proposed behavior:** Persist completion or snooze locally, cancel that reminder's pending requests, clear delivered notifications separately, and install the new snooze schedule where appropriate. Persist a sync operation for later retry so lack of connectivity does not prevent local completion. Notification dismissal should not count as task completion. Validate races with imminent delivery and interrupted action processing; this research establishes no atomic transaction between storage and notification scheduling.

Delivered-notification queries report notifications still present in Notification Center, not a complete delivery or user-attention history. [Delivered notifications](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/getdeliverednotifications(completionhandler:))

## Background work cannot guarantee replenishment

**Documented:** `BGTaskRequest.earliestBeginDate` sets the earliest allowed execution, not a deadline or guaranteed launch time. Background refresh can improve coverage opportunistically; it cannot guarantee that a finite batch is replenished before exhaustion. [Background task timing](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate)

Silent/background APNs pushes are low priority and not guaranteed. Apple advises trying no more than two or three per hour; that is guidance, not a guaranteed quota. Updates may be delayed or replaced by newer ones, and held updates are discarded if the app is killed or force-quit. A delivered background update gives about 30 seconds to work. These pushes use `content-available: 1`, background push type, and priority 5. [Pushing background updates](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app)

**Consequence:** “AI creates reminder → silent push → phone schedules it before due” is not a supported reliability guarantee.

## Visible APNs and reminders created while Pester is closed

**Documented:** APNs is best effort and can reorder messages. Apple describes storing only one notification per bundle ID, usually the latest but without guaranteed selection for closely spaced messages. Storage can last up to 30 days subject to expiration. Expiration zero requests one attempt without storage; nonzero expiration permits retries/storage. Expiration is itself best effort, so late delivery remains possible. Priority 10 requests immediate sending, not guaranteed presentation. Collapse IDs merge requests; they do not provide a durable offline queue for every reminder. [Sending notification requests to APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns)

**Proposed direction:** A server could send a visible alert at due time even if phone sync never ran. Include enough payload information for a useful alert without app execution. Use silent pushes as sync hints; use acknowledged local schedules for offline coverage. Explicitly design who sends each occurrence: independently sending local and remote alerts invites duplicates. An offline phone also cannot immediately learn that an AI completed a reminder and cancel its stale local nags.

**Unknown:** This research did not establish a precise current guarantee for visible alerts after user force-quit. Test that separately; restrictions on silent-push execution do not automatically describe visible-alert presentation.

A notification service extension modifies eligible visible remote alerts with `mutable-content: 1`. It has limited execution time and falls back to the original notification if it fails to finish. It is not a general background daemon. [Notification service extension](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension)

The content handler has no more than about 30 seconds, and removing alert text does not provide a supported way to suppress the notification: Apple says it delivers the original content. Treat extension-assisted local scheduling or stale-alert filtering as separate experiments, not reliability guarantees. [Extension content handler](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension/didreceive(_:withcontenthandler:))

## A newer alternative: AlarmKit

**Documented:** AlarmKit, introduced in iOS/iPadOS 26, supplies system alarms that break through Silent mode and Focus. Users authorize alarms per app and can revoke that permission. Alarm UI supports stopping and optional snoozing/custom actions. Fixed schedules represent absolute dates; relative schedules use a time of day with optional weekly recurrence. A snooze countdown is distinct from automatic unattended nagging. See [Apple’s AlarmKit session](https://developer.apple.com/videos/play/wwdc2025/230/).

Scheduling requires AlarmKit authorization and a nonempty `NSAlarmKitUsageDescription` in Info.plist. Apple’s sample demonstrates one-time alarms, weekly repeating alarms, and timers. See [Scheduling an alarm with AlarmKit](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit).

**Proposal:** Evaluate AlarmKit separately if alarm-style interruption is desirable. Pester currently targets iOS 16+, so adopting it would need availability checks or a deployment-target decision. Do not assume it supplies an arbitrary “every N minutes until completed” rule or solves remotely created reminders while the app cannot execute. Alarm scheduling capacity, unattended alert duration, dismissal behavior, and reboot behavior need separate verification. This is an alternative worth testing, not a decision to migrate.

## Physical-iPhone experiment plan

Keep this within the notification proof of concept before building the backend or broader UI. The original ten-second locked-phone alert is **user-confirmed**. All other results below are **not yet tested**.

| Test | What to record |
| --- | --- |
| Existing ten-second alert, phone locked | Actual presentation and sound; user confirmation. |
| 60-second repeat for multiple cycles | Cadence with app closed, then force-quit and airplane mode. |
| Reboot and power-off cases | Future alerts after reboot, before first unlock, and missed due times while powered off. |
| Arbitrary future due time plus five-minute batch | No premature alerts, intended cadence, and behavior after batch exhaustion without reopening. |
| 63/64/65/80 unique pending requests | Add errors, returned pending IDs, actual deliveries; repeat with mixed one-shot/repeating requests. |
| Complete/snooze from Lock Screen | Offline and force-quit handling, durable state, cancellation, and races near the next alert. |
| Presentation settings | Ordinary vs Time Sensitive under Focus, Summary, Silent mode, disabled sounds, revoked permission, and Apple Watch routing if paired. |
| Later: visible and silent APNs | Closed/force-quit/offline cases, Background App Refresh off, expiration, and multiple reminders queued offline. |
| Optional: AlarmKit on iOS 26+ | Authorization, Focus/Silent breakthrough, snooze/stop behavior, reboot, and capacity. |

For each run record device model, iOS build, app build, timezone, permission/interruption settings, app state, network state, reminder/request IDs, intended fire times, scheduling errors, pending snapshots, and observed banner/sound times. Pending requests and APNs acceptance are diagnostic evidence, not proof of delivery. Use [Apple's Push Notification Console](https://developer.apple.com/documentation/usernotifications/testing-notifications-using-the-push-notification-console) for later push tests.

## Decisions still open

- Accept a finite unattended nag horizon, restrict reminder patterns, or investigate a different scheduling approach?
- Should urgent reminders use alarm-style interruption, and is requiring iOS 26 acceptable?
- How should the API report reminders saved on the server but not yet installed on the phone?
- What duplicate/stale-alert tradeoff is acceptable during sync outages or remote completion?

No architecture choice or physical-delivery guarantee is established by these notes. The next gate is repeated locked-phone delivery and Complete/Snooze action validation on the user's iPhone.


## Device feedback and next experiment — 2026-09-10

**User-reported observations, original repeating request:** Three initial pesters, a left-swipe/clear attempt that did not stop pestering, two further pesters, Snooze followed by another alert, and Complete followed by several minutes of waiting. The user described pestering as working. Only one notification was visible. Watch alerts reportedly resumed after swiping and re-delivery, rather than appearing on every pester. Device/OS versions, exact timestamps, Watch lock/connectivity state, and whether Clear removed the visible card were not recorded. Do not infer that Pester can prevent notification dismissal.

**New implementation, build verified but not phone verified:** A batch of 20 uniquely identified one-shot requests, first at +60 seconds, then every 60 seconds through +20 minutes. Snooze replaces all test requests with a fresh batch at +180, +240, …, +1320 seconds. Titles become “After snooze · Pester N”; numbering restarts at 1 and identifies scheduled occurrences, not proven deliveries. Complete clears the batch and legacy test requests. Unique requests may accumulate or group visually, unlike the previously observed single repeating notification. There is no automatic replenishment after the batch ends.

**Interactions:** The delegate receives app-opening taps and custom Complete/Snooze actions. The category now opts into `customDismissAction` to log explicit dismissal callbacks. Apple says ignoring a notification or flicking away a banner does not trigger this callback; it is not a universal swipe or read detector. Logs are local, capped at 40 entries, and persisted across app launches. There is no backend event transmission. Taps/dismissals only log; they do not trigger another alert or complete the reminder. [Response types](https://developer.apple.com/documentation/usernotifications/unnotificationresponse), [dismissal semantics](https://developer.apple.com/documentation/usernotifications/unnotificationdismissactionidentifier).

**Watch:** Apple documents routing to either phone or Watch by default, based on lock state and notification settings. This does not establish the cause of skipped repeat alerts. Compare numbered alerts with the phone locked, Watch worn/unlocked, mirroring enabled, and connectivity/Focus noted. [Apple routing and settings](https://support.apple.com/en-us/108274).

**Next device checks:** Observe Pester 1/2/3; snooze and verify silence for three minutes then “After snooze · Pester 1”, followed one minute later by Pester 2. Open a notification and inspect the log; explicitly clear another and check whether iOS reports dismissal. Confirm these actions leave future alerts scheduled. Complete and verify several minutes without another alert. Repeat on Watch and record which numbered alerts actually appear. Separately allow all 20 requests to expire to verify the finite horizon; pending counts are not delivery counts.


## Third-party smartwatch follow-up — 2026-09-10

**User-confirmed:** The device is a third-party smartwatch, not an Apple Watch. The numbered one-shot alerts now produce individual watch alerts. Three-minute snooze passed. The user did not observe swipe-dismiss detection; exact gesture and callback behavior remain unresolved. The earlier Apple Watch routing discussion does not explain this accessory.

**Generic documentation:** Apple's archived [Apple Notification Center Service (ANCS) specification](https://developer.apple.com/library/archive/documentation/CoreBluetooth/Reference/AppleNotificationCenterServiceSpecification/Specification/Specification.html) documents a Bluetooth accessory interface for notification-added, modified, and removed events. Events carry a notification UID; accessories can retrieve notification attributes and request supported actions. ANCS UIDs are session-scoped protocol identifiers, not the app's request identifier strings.

**Hypotheses, not conclusions:** The watch may alert on added notifications but quietly process modifications, or may filter duplicate content. We changed both request identity/scheduling (one repeat to unique one-shots) and title/body, so this experiment does not isolate the cause. ANCS use by this particular watch has not been verified without its model/vendor documentation or a protocol trace. A future controlled test could compare unique requests with identical text against unique requests with changing text; no app changes were made for this research.

Apple also documents a newer [accessory notification forwarding framework](https://developer.apple.com/documentation/accessorynotifications), with customer availability restricted to EU-located devices using an EU Apple Account, and [accessory update/removal handling](https://developer.apple.com/documentation/AccessoryTransportExtension/receiving-ios-notifications-on-an-accessory). Its update guidance says to update without alerting again. This is a separate mechanism and does not establish which protocol this watch uses.

**Release scope:** Preserve the tested finite-batch experiment for v0.1.0. Swipe-dismiss logging, batch exhaustion, reboot/force-quit behavior, and isolated smartwatch causality remain open. The user-authored `docs/ROADMAP.md` defines later milestones; no implementation was added from it in this follow-up.


## Controlled same-text experiment — 2026-09-10

Changed only notification text and supporting test labels/logging: all 20 separate requests now use title “Pester test reminder” and body “Still here! Complete to stop, or snooze for 3 minutes.” Snoozed batches use identical text too. Existing distinct request IDs, grouping, sound, actions, minute cadence, finite batch size, and three-minute snooze timing are retained. Internal request IDs are visible in diagnostic log entries, not notification text. Phone/watch results remain pending.

Install the update, Complete any previously scheduled batch, then Start same-text test. Observe at least three alerts on the third-party watch without dismissing between them. If all arrive, changed content is not necessary for individual watch alerts under these test conditions; this still does not prove the watch's underlying protocol. Repeat after snooze and verify completion stops future alerts.


## v0.1.0 acceptance — 2026-09-10

The user confirmed repeated alerts on the third-party smartwatch with identical notification title/body, and receipt of a scheduled notification after killing the background iPhone app. Changing notification text is therefore not necessary for repeated watch alerts in this tested separate-request configuration. The watch protocol and the original repeating-request behavior remain unproven.

The user accepted the notification foundation as v0.1.0 complete. Earlier Complete and three-minute Snooze results remain recorded above. This acceptance does not establish reboot behavior, full 20-alert batch exhaustion, indefinite unattended pestering, or dismissal callback reliability. No application code changed after the successful same-text test.
