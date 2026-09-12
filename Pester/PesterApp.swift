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
            await TaskStore.shared.task(for: notification.request)?.notificationSuppressedInForeground(notification.request)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            defer { completionHandler() }
            await TaskStore.shared.task(for: response.notification.request)?.handle(response)
        }
    }
}

@MainActor
final class TaskStore: ObservableObject {
    struct StoredTask: Codable {
        let id: UUID
        let storageID: String
        var title: String
        var dueAt: Date?
        var pesterMinutes: Int
        var snoozeMinutes: Int
        var snoozedUntil: Date?
        var completedAt: Date?
        let createdAt: Date
        var updatedAt: Date
    }

    static let shared = TaskStore()

    @Published private(set) var tasks: [PesterTask] = []

    private let defaults = UserDefaults.standard
    private let tasksKey = "pester.v04.tasks"
    private let migrationKey = "pester.v04.migratedLegacyTasks"
    private var refreshTask: Task<Void, Never>?

    private init() {
        if let data = defaults.data(forKey: tasksKey),
           let records = try? JSONDecoder().decode([StoredTask].self, from: data) {
            tasks = records.map(PesterTask.init(record:))
        } else if !defaults.bool(forKey: migrationKey) {
            tasks = PesterTask.legacyTasks()
            defaults.set(true, forKey: migrationKey)
        }
        attachPersistence()
        save()
    }

    func task(for request: UNNotificationRequest) -> PesterTask? {
        tasks.first { $0.matches(request) }
    }

    @discardableResult
    func create(title: String, dueAt: Date, pesterMinutes: Int, snoozeMinutes: Int) async -> PesterTask? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, dueAt > Date() else { return nil }
        let now = Date()
        let task = PesterTask(record: StoredTask(
            id: UUID(),
            storageID: UUID().uuidString.lowercased(),
            title: trimmedTitle,
            dueAt: dueAt,
            pesterMinutes: pesterMinutes,
            snoozeMinutes: snoozeMinutes,
            snoozedUntil: nil,
            completedAt: nil,
            createdAt: now,
            updatedAt: now
        ))
        attach(task)
        tasks.append(task)
        save()
        await task.schedule(at: dueAt)
        return task
    }

    func update(_ task: PesterTask, title: String, dueAt: Date, pesterMinutes: Int, snoozeMinutes: Int) async {
        guard tasks.contains(where: { $0.id == task.id }) else { return }
        await task.update(title: title, dueAt: dueAt, pesterMinutes: pesterMinutes, snoozeMinutes: snoozeMinutes)
    }

    func delete(_ task: PesterTask) async {
        await task.removePermanently()
        tasks.removeAll { $0.id == task.id }
        save()
    }

    private func attachPersistence() {
        for task in tasks { attach(task) }
    }

    private func attach(_ task: PesterTask) {
        task.onChange = { [weak self] in
            self?.save()
            self?.scheduleRefresh()
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000)
            guard !Task.isCancelled else { return }
            self?.objectWillChange.send()
            self?.refreshTask = nil
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tasks.map(\.record)) else { return }
        defaults.set(data, forKey: tasksKey)
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
    let id: UUID
    @Published private(set) var title: String
    @Published private(set) var dueAt: Date?
    @Published private(set) var snoozedUntil: Date?
    @Published private(set) var completedAt: Date?
    let createdAt: Date
    @Published private(set) var updatedAt: Date
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
    var onChange: (() -> Void)?

    fileprivate init(record: TaskStore.StoredTask) {
        id = record.id
        storageID = record.storageID
        title = record.title
        dueAt = record.dueAt
        snoozedUntil = record.snoozedUntil
        completedAt = record.completedAt
        createdAt = record.createdAt
        updatedAt = record.updatedAt
        let defaults = UserDefaults.standard
        let savedInterval = defaults.integer(forKey: "pester.v02.\(storageID).interval")
        let savedSnooze = defaults.integer(forKey: "pester.v02.\(storageID).snooze")
        pesterMinutes = (1...60).contains(savedInterval) ? savedInterval : record.pesterMinutes
        snoozeMinutes = (1...60).contains(savedSnooze) ? savedSnooze : record.snoozeMinutes
        events = defaults.stringArray(forKey: "pester.v02.\(storageID).events") ?? []
        scheduledStart = defaults.object(forKey: "pester.v03.\(storageID).scheduledStart") as? Date
    }

    fileprivate static func legacyTasks() -> [PesterTask] {
        let now = Date()
        return [
            PesterTask(record: TaskStore.StoredTask(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, storageID: "a", title: "Reminder A",
                dueAt: UserDefaults.standard.object(forKey: "pester.v03.a.scheduledStart") as? Date,
                pesterMinutes: 1, snoozeMinutes: 3, snoozedUntil: nil, completedAt: nil, createdAt: now, updatedAt: now
            )),
            PesterTask(record: TaskStore.StoredTask(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, storageID: "b", title: "Reminder B",
                dueAt: UserDefaults.standard.object(forKey: "pester.v03.b.scheduledStart") as? Date,
                pesterMinutes: 2, snoozeMinutes: 3, snoozedUntil: nil, completedAt: nil, createdAt: now, updatedAt: now
            ))
        ]
    }

    fileprivate var record: TaskStore.StoredTask {
        TaskStore.StoredTask(
            id: id, storageID: storageID, title: title, dueAt: dueAt,
            pesterMinutes: pesterMinutes, snoozeMinutes: snoozeMinutes,
            snoozedUntil: snoozedUntil, completedAt: completedAt,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }

    fileprivate func matches(_ request: UNNotificationRequest) -> Bool {
        let payload = request.content.userInfo
        return id.uuidString == payload["taskID"] as? String || storageID == payload["testID"] as? String
    }

    private func saveSettings(interval: Int, snooze: Int) {
        pesterMinutes = interval
        snoozeMinutes = snooze
        UserDefaults.standard.set(interval, forKey: "pester.v02.\(storageID).interval")
        UserDefaults.standard.set(snooze, forKey: "pester.v02.\(storageID).snooze")
        markUpdated()
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
        onChange?()
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
        let dates = requests.compactMap(scheduledFireDate(for:)).sorted()
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
        onChange?()
    }

    func start(snoozing: Bool = false) async {
        await serially {
            if snoozing {
                await self.installBatch(snoozing: true)
            } else if UIApplication.shared.applicationState == .active {
                self.dueAt = Date()
                self.completedAt = nil
                self.snoozedUntil = nil
                self.markUpdated()
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
            self.dueAt = nil
            self.snoozedUntil = nil
            self.completedAt = nil
            self.markUpdated()
            await self.updateStatus()
            self.record("Schedule deleted.")
        }
    }

    func update(title: String, dueAt: Date, pesterMinutes: Int, snoozeMinutes: Int) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty,
              (1...60).contains(pesterMinutes),
              (1...60).contains(snoozeMinutes) else { return }
        let dueDateChanged = self.dueAt != dueAt
        guard !dueDateChanged || dueAt > Date() else { return }
        await serially {
            let titleChanged = self.title != trimmedTitle
            let durationsChanged = self.pesterMinutes != pesterMinutes || self.snoozeMinutes != snoozeMinutes

            self.title = trimmedTitle
            if dueDateChanged {
                await self.installBatch(
                    snoozing: false,
                    interval: pesterMinutes,
                    snooze: snoozeMinutes,
                    scheduledFor: dueAt
                )
            } else if durationsChanged {
                let pending = await self.center.pendingNotificationRequests()
                if pending.contains(where: { self.allIDs.contains($0.identifier) }) {
                    let isUpcoming = self.lifecycleState == .upcoming || self.lifecycleState == .snoozed
                    let futureStart = isUpcoming ? self.scheduledStart : nil
                    await self.installBatch(
                        snoozing: self.lifecycleState == .snoozed,
                        interval: pesterMinutes,
                        snooze: snoozeMinutes,
                        scheduledFor: futureStart
                    )
                } else {
                    self.saveSettings(interval: pesterMinutes, snooze: snoozeMinutes)
                    await self.updateStatus()
                    self.record("Settings saved: pester \(pesterMinutes) min, snooze \(snoozeMinutes) min.")
                }
            } else if titleChanged {
                self.markUpdated()
                await self.refreshPendingNotificationTitles()
                self.record("Title updated; pending alert times preserved.")
            }
        }
    }

    private func refreshPendingNotificationTitles() async {
        for request in await pendingRequests() {
            guard let fireDate = scheduledFireDate(for: request), fireDate > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = ""
            content.sound = request.content.sound
            content.categoryIdentifier = request.content.categoryIdentifier
            content.threadIdentifier = request.content.threadIdentifier
            content.userInfo = request.content.userInfo
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, fireDate.timeIntervalSinceNow),
                repeats: false
            )
            do {
                try await center.add(UNNotificationRequest(
                    identifier: request.identifier,
                    content: content,
                    trigger: trigger
                ))
            } catch {
                record("Could not update pending notification title: \(error.localizedDescription)")
            }
        }
    }

    fileprivate func removePermanently() async {
        await serially {
            self.center.removePendingNotificationRequests(withIdentifiers: self.allIDs)
            self.center.removeDeliveredNotifications(withIdentifiers: self.allIDs)
            let defaults = UserDefaults.standard
            [self.generationKey, self.logKey, self.stateKey, self.scheduledStartKey,
             "pester.v02.\(self.storageID).interval", "pester.v02.\(self.storageID).snooze"].forEach {
                defaults.removeObject(forKey: $0)
            }
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
            if snoozing {
                snoozedUntil = firstFireDate
                completedAt = nil
            } else if let scheduledFor {
                dueAt = scheduledFor
                snoozedUntil = nil
                completedAt = nil
            }
            for (index, id) in self.allIDs.enumerated() {
                let content = UNMutableNotificationContent()
                let count = index + 1
                let fireDate = firstFireDate.addingTimeInterval(TimeInterval(index * interval * 60))
                content.title = title
                content.body = ""
                content.sound = .default
                content.categoryIdentifier = "pester.test"
                content.threadIdentifier = "pester.test.\(self.id)"
                content.userInfo = [
                    "generation": generation,
                    "taskID": self.id.uuidString,
                    "testID": self.storageID,
                    "sequence": count,
                    "fireAt": fireDate.timeIntervalSince1970
                ]
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
        snoozedUntil = nil
        completedAt = Date()
        markUpdated()
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
        for task in TaskStore.shared.tasks where task.id != id {
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

    private func scheduledFireDate(for request: UNNotificationRequest) -> Date? {
        if let timestamp = request.content.userInfo["fireAt"] as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        }

        // Requests created before v0.4.1-0010 only persisted a relative trigger.
        // Reconstruct their absolute fire time from the stable batch start and
        // identifier sequence so reading status never moves the displayed time.
        if let start = scheduledStart,
           let sequenceText = request.identifier.split(separator: ".").last,
           let sequence = Int(sequenceText),
           (1...Self.batchCount).contains(sequence) {
            return start.addingTimeInterval(TimeInterval((sequence - 1) * pesterMinutes * 60))
        }

        return (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
    }

    private func markUpdated() {
        updatedAt = Date()
        onChange?()
    }
}
