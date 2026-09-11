import SwiftUI
import UIKit
import UserNotifications

@main
struct PesterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([UNNotificationCategory(identifier: "pester.test", actions: [
            UNNotificationAction(identifier: "complete", title: "Complete", options: []),
            UNNotificationAction(identifier: "snooze", title: "Snooze", options: [])
        ], intentIdentifiers: [], options: [.customDismissAction])])
        // Retire request identifiers from the original single-reminder experiment.
        let legacyIDs = (1...20).map { "pester.numbered-test.\($0)" } + ["pester.repeating-test", "pester.notification-test"]
        center.removePendingNotificationRequests(withIdentifiers: legacyIDs)
        center.removeDeliveredNotifications(withIdentifiers: legacyIDs)
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Pester stays quiet while its UI is visible. If a snooze expires while
        // the app remains open, reset that task and arm it for the next exit.
        completionHandler([])
        Task { @MainActor in
            await PesterTask.task(for: notification.request)?.notificationSuppressedInForeground(notification.request)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            defer { completionHandler() }
            await PesterTask.task(for: response.notification.request)?.handle(response)
        }
    }
}

@MainActor
final class PesterTask: ObservableObject, Identifiable {
    enum TaskState: String {
        case notScheduled = "Not scheduled"
        case upcoming = "Upcoming"
        case active = "Active"
        case snoozed = "Snoozed"
        case overdue = "Overdue"
        case completed = "Completed"
    }

    private enum LifecycleState: String {
        case idle
        case active
        case upcoming
        case snoozed
        case pausedWhileOpen
        case completed
    }

    static let batchCount = 8
    static let tasks = [
        PesterTask(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, storageID: "a", title: "Reminder A", defaultInterval: 1),
        PesterTask(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, storageID: "b", title: "Reminder B", defaultInterval: 2)
    ]

    static func task(for request: UNNotificationRequest) -> PesterTask? {
        let payload = request.content.userInfo
        return tasks.first {
            $0.id.uuidString == payload["taskID"] as? String || $0.storageID == payload["testID"] as? String
        }
    }
    let id: UUID
    let title: String
    private let storageID: String
    private var allIDs: [String] { (1...Self.batchCount).map { "pester.v02.\(storageID).\($0)" } }
    private var generationKey: String { "pester.v02.\(storageID).generation" }
    private var logKey: String { "pester.v02.\(storageID).events" }
    private var stateKey: String { "pester.v02.\(storageID).state" }
    private var scheduledStartKey: String { "pester.v03.\(storageID).scheduledStart" }
    @Published private(set) var busy = false
    @Published private(set) var active = false
    @Published private(set) var status = "Ready."
    @Published private(set) var showSettings = false
    @Published private(set) var events: [String]
    @Published private(set) var pesterMinutes: Int
    @Published private(set) var snoozeMinutes: Int
    @Published private(set) var scheduledStart: Date?
    @Published private(set) var state: TaskState = .notScheduled
    @Published private(set) var nextPesterAt: Date?
    @Published private(set) var pesterCount = 0
    let maxPesterCount = PesterTask.batchCount

    private init(id: UUID, storageID: String, title: String, defaultInterval: Int) {
        self.id = id
        self.storageID = storageID
        self.title = title
        let defaults = UserDefaults.standard
        let interval = defaults.integer(forKey: "pester.v02.\(storageID).interval")
        let snooze = defaults.integer(forKey: "pester.v02.\(storageID).snooze")
        pesterMinutes = (1...60).contains(interval) ? interval : defaultInterval
        snoozeMinutes = (1...60).contains(snooze) ? snooze : 3
        events = defaults.stringArray(forKey: "pester.v02.\(storageID).events") ?? []
        scheduledStart = defaults.object(forKey: "pester.v03.\(storageID).scheduledStart") as? Date
    }

    private func saveSettings(interval: Int, snooze: Int) {
        pesterMinutes = interval
        snoozeMinutes = snooze
        UserDefaults.standard.set(interval, forKey: "pester.v02.\(storageID).interval")
        UserDefaults.standard.set(snooze, forKey: "pester.v02.\(storageID).snooze")
    }

    private var lifecycleState: LifecycleState {
        get {
            guard let raw = UserDefaults.standard.string(forKey: stateKey),
                  let state = LifecycleState(rawValue: raw) else {
                return UserDefaults.standard.string(forKey: generationKey) == nil ? .idle : .active
            }
            return state
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: stateKey) }
    }

    func apply(interval: Int, snooze: Int) async {
        guard (1...60).contains(interval), (1...60).contains(snooze) else { return }
        await serially {
            let pending = await self.center.pendingNotificationRequests()
            if pending.contains(where: { self.allIDs.contains($0.identifier) }) {
                let isUpcoming = self.lifecycleState == .upcoming || self.lifecycleState == .snoozed
                let futureStart = isUpcoming ? self.scheduledStart : nil
                await self.installBatch(snoozing: self.lifecycleState == .snoozed, interval: interval, snooze: snooze, scheduledFor: futureStart)
            } else {
                self.saveSettings(interval: interval, snooze: snooze)
                await self.updateStatus()
                self.record("Settings saved: pester \(interval) min, snooze \(snooze) min.")
            }
        }
    }

    private let center = UNUserNotificationCenter.current()
    // Serialize UI and background actions across suspension points; never drop Complete.
    private var lastOperation: Task<Void, Never>?

    private func serially(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = lastOperation
        let task = Task { @MainActor in
            await previous?.value
            busy = true
            await operation()
            busy = false
        }
        lastOperation = task
        await task.value
    }

    func record(_ message: String) {
        events.insert("\(Date().formatted(date: .omitted, time: .standard)) — \(message)", at: 0)
        events = Array(events.prefix(40))
        UserDefaults.standard.set(events, forKey: logKey)
    }

    func appBecameActive() async {
        await serially {
            self.record("App opened — reset check")
            let pending = await self.pendingRequests()
            let hasLifecycle = UserDefaults.standard.string(forKey: self.generationKey) != nil
            let state = self.lifecycleState

            if (state == .upcoming || state == .snoozed), !pending.isEmpty {
                if let start = self.scheduledStart, start <= Date() {
                    self.lifecycleState = .active
                    self.record("Scheduled start reached; active pester count preserved.")
                } else {
                    self.record("Upcoming schedule preserved; pester count not reset.")
                }
                await self.updateStatus()
            } else if state == .pausedWhileOpen {
                await self.updateStatus()
            } else if hasLifecycle && pending.isEmpty && state != .completed {
                self.pauseAndReset(reason: "overdue")
            } else if state == .active {
                self.record("Active pester count preserved.")
                await self.updateStatus()
            } else {
                await self.updateStatus()
            }
        }
    }

    func appBecameBackground() async {
        await serially {
            guard self.lifecycleState == .pausedWhileOpen else {
                await self.updateStatus()
                return
            }
            await self.installBatch(snoozing: false)
            self.record("App left foreground — pestering restarted at 1/\(Self.batchCount).")
        }
    }

    func notificationSuppressedInForeground(_ request: UNNotificationRequest) async {
        await serially {
            self.record("Foreground alert suppressed: \(request.identifier)")
            let pending = await self.pendingRequests()
            if pending.isEmpty,
               UserDefaults.standard.string(forKey: self.generationKey) != nil,
               self.lifecycleState != .completed {
                self.pauseAndReset(reason: "overdue")
            } else {
                await self.updateStatus()
            }
        }
    }

    private func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests().filter { self.allIDs.contains($0.identifier) }
    }

    private func pauseAndReset(reason: String) {
        center.removePendingNotificationRequests(withIdentifiers: allIDs)
        center.removeDeliveredNotifications(withIdentifiers: allIDs)
        lifecycleState = .pausedWhileOpen
        setScheduledStart(nil)
        active = true
        state = .overdue
        nextPesterAt = nil
        pesterCount = Self.batchCount
        status = "Pester count reset from \(reason). Leave Pester to restart at 1/\(Self.batchCount)."
        record("Pester count reset from \(reason); waiting for app to leave foreground.")
    }

    private func updateStatus() async {
        let requests = await pendingRequests()
        if (lifecycleState == .upcoming || lifecycleState == .snoozed),
           let start = scheduledStart,
           start <= Date(),
           !requests.isEmpty {
            lifecycleState = .active
        }
        let state = lifecycleState
        active = !requests.isEmpty || state == .pausedWhileOpen
        let dates = requests.compactMap { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() }.sorted()
        nextPesterAt = dates.first
        pesterCount = min(Self.batchCount, max(0, Self.batchCount - requests.count))
        if state == .pausedWhileOpen {
            self.state = .overdue
            status = "Pester count reset. Leave Pester to restart at 1/\(Self.batchCount)."
        } else if let next = dates.first, let end = dates.last {
            let label: String
            if state == .snoozed {
                self.state = .snoozed
                label = "Snoozed"
            } else if state == .upcoming {
                self.state = .upcoming
                label = "Upcoming"
            } else {
                self.state = .active
                label = "Active"
            }
            status = "\(label): \(requests.count) pending. Next expected: \(next.formatted(date: .omitted, time: .standard)). Last scheduled: \(end.formatted(date: .omitted, time: .standard))."
        } else if UserDefaults.standard.string(forKey: generationKey) != nil, state != .completed {
            active = true
            self.state = .overdue
            pesterCount = Self.batchCount
            status = "Overdue: all \(Self.batchCount) pester notifications were exhausted. Open Pester to reset."
        } else if state == .completed {
            self.state = .completed
            pesterCount = 0
            status = "Completed. No alerts remain scheduled."
        } else {
            self.state = .notScheduled
            pesterCount = 0
            status = "Not started. No alerts are scheduled."
        }
    }

    func start(snoozing: Bool = false) async {
        await serially {
            if snoozing {
                await self.installBatch(snoozing: true)
            } else if UIApplication.shared.applicationState == .active {
                if UserDefaults.standard.string(forKey: self.generationKey) == nil {
                    UserDefaults.standard.set(UUID().uuidString, forKey: self.generationKey)
                }
                self.pauseAndReset(reason: "start")
            } else {
                await self.installBatch(snoozing: false)
            }
        }
        if snoozing { await Self.resetOtherOverdueTasks(excluding: id) }
    }

    func schedule(at date: Date) async {
        await serially {
            guard date > Date() else {
                self.status = "Choose a future date and time. The existing schedule was not changed."
                return
            }
            await self.installBatch(snoozing: false, scheduledFor: date)
        }
    }

    func deleteSchedule() async {
        await serially {
            self.center.removePendingNotificationRequests(withIdentifiers: self.allIDs)
            self.center.removeDeliveredNotifications(withIdentifiers: self.allIDs)
            UserDefaults.standard.removeObject(forKey: self.generationKey)
            self.lifecycleState = .idle
            self.setScheduledStart(nil)
            await self.updateStatus()
            self.record("Schedule deleted.")
        }
    }

    private func installBatch(snoozing: Bool, interval: Int? = nil, snooze: Int? = nil, scheduledFor: Date? = nil) async {
        let interval = interval ?? pesterMinutes
        let snooze = snooze ?? snoozeMinutes
        showSettings = false
        var replacing = false
        do {
            var settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
                settings = await center.notificationSettings()
            }
            guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
                status = "Notifications are not allowed. Enable them in Settings and try again. Previous requests have not been changed."
                showSettings = true
                record("Schedule unchanged: notification permission unavailable.")
                return
            }
            // This experiment intentionally uses a finite batch: a repeating trigger
            // cannot change its content or have a distinct initial snooze delay.
            let generation = UUID().uuidString
            center.removePendingNotificationRequests(withIdentifiers: self.allIDs)
            center.removeDeliveredNotifications(withIdentifiers: self.allIDs)
            replacing = true
            UserDefaults.standard.set(generation, forKey: generationKey)
            let firstFireDate = scheduledFor ?? Date().addingTimeInterval(TimeInterval((snoozing ? snooze : interval) * 60))
            lifecycleState = snoozing ? .snoozed : (scheduledFor != nil ? .upcoming : .active)
            setScheduledStart(firstFireDate)
            for (index, id) in self.allIDs.enumerated() {
                let content = UNMutableNotificationContent()
                let count = index + 1
                content.title = "\(title) · Pester \(count)/\(self.allIDs.count)"
                content.body = "Pester count \(count) of \(self.allIDs.count). Complete to stop, or snooze for \(snooze) minutes."
                content.sound = .default
                content.categoryIdentifier = "pester.test"
                content.threadIdentifier = "pester.test.\(self.id)"
                content.userInfo = ["generation": generation, "taskID": self.id.uuidString, "testID": self.storageID]
                let fireDate = firstFireDate.addingTimeInterval(TimeInterval(index * interval * 60))
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fireDate.timeIntervalSinceNow), repeats: false)
                try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
            saveSettings(interval: interval, snooze: snooze)
            await updateStatus()
            if snoozing {
                record("Snoozed \(snooze) min; then every \(interval) min.")
                status = "Snoozed for \(snooze) minutes. " + status
            } else if let scheduledFor {
                record("Scheduled for \(scheduledFor.formatted(date: .abbreviated, time: .shortened)); then every \(interval) min.")
                status = "Future batch scheduled. " + status
            } else {
                record("Started \(Self.batchCount) alerts, every \(interval) min.")
                status = "Batch scheduled. " + status
            }
            if settings.alertSetting != .enabled || settings.authorizationStatus == .provisional {
                status += " Alerts may be quiet or disabled; check Settings."
                showSettings = true
            }
        } catch {
            if replacing {
                center.removePendingNotificationRequests(withIdentifiers: self.allIDs)
                UserDefaults.standard.removeObject(forKey: generationKey)
                lifecycleState = .idle
                setScheduledStart(nil)
            }
            await updateStatus()
            status = "Could not schedule: \(error.localizedDescription). " + (replacing ? "Partial batch cancelled. " : "") + status
            record(status)
        }
    }

    func complete() async {
        await serially { await self.cancelBatch() }
        await Self.resetOtherOverdueTasks(excluding: id)
    }

    private func cancelBatch() async {
        center.removePendingNotificationRequests(withIdentifiers: self.allIDs)
        center.removeDeliveredNotifications(withIdentifiers: self.allIDs)
        UserDefaults.standard.removeObject(forKey: generationKey)
        lifecycleState = .completed
        setScheduledStart(nil)
        await updateStatus()
        status = active ? "A notification is still pending. Try Complete again." : "Completed. No task alerts remain scheduled."
        record(status)
    }

    func handle(_ response: UNNotificationResponse) async {
        var handledLifecycleAction = false
        await serially {
            let request = response.notification.request
            guard self.allIDs.contains(request.identifier) else { return }
            let action = response.actionIdentifier
            let name: String
            switch action {
            case "complete": name = "Complete selected"
            case "snooze": name = "Snooze selected"
            case UNNotificationDefaultActionIdentifier: name = "Opened app from notification"
            case UNNotificationDismissActionIdentifier: name = "Explicit dismissal reported by iOS"
            default: name = "Other response: \(action)"
            }
            self.record("\(name): \(request.identifier) — \(request.content.title)")
            guard action == "complete" || action == "snooze" else { return }
            let generation = request.content.userInfo["generation"] as? String
            let current = UserDefaults.standard.string(forKey: self.generationKey)
            // A delayed action on a cleared notification must not modify a newer batch.
            guard generation == current else {
                self.record("Ignored action from an older batch.")
                return
            }
            if action == "complete" { await self.cancelBatch() }
            else { await self.installBatch(snoozing: true) }
            handledLifecycleAction = true
        }
        if handledLifecycleAction { await Self.resetOtherOverdueTasks(excluding: id) }
    }

    private static func resetOtherOverdueTasks(excluding id: UUID) async {
        for task in tasks where task.id != id {
            await task.resetIfOverdue()
        }
    }

    private func resetIfOverdue() async {
        await serially {
            let pending = await self.pendingRequests()
            let hasLifecycle = UserDefaults.standard.string(forKey: self.generationKey) != nil
            let state = self.lifecycleState
            guard hasLifecycle,
                  pending.isEmpty,
                  state != .completed,
                  state != .idle else {
                return
            }

            if UIApplication.shared.applicationState == .active {
                self.pauseAndReset(reason: "overdue task action")
            } else {
                await self.installBatch(snoozing: false)
                self.record("Overdue pester count reset by another task's Complete/Snooze action; restarted at 1/\(Self.batchCount).")
            }
        }
    }

    private func setScheduledStart(_ date: Date?) {
        scheduledStart = date
        if let date {
            UserDefaults.standard.set(date, forKey: scheduledStartKey)
        } else {
            UserDefaults.standard.removeObject(forKey: scheduledStartKey)
        }
    }
}
