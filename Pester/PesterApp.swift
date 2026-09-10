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
        let actions = [
            UNNotificationAction(identifier: "complete", title: "Complete", options: []),
            UNNotificationAction(identifier: "snooze", title: "Snooze 3 minutes", options: [])
        ]
        center.setNotificationCategories([UNNotificationCategory(identifier: "pester.test", actions: actions, intentIdentifiers: [], options: [.customDismissAction])])
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in
            PesterTest.shared.record("Foreground presentation requested: \(notification.request.content.title)")
            completionHandler([.banner, .sound, .list])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            defer { completionHandler() }
            await PesterTest.shared.handle(response)
        }
    }
}

@MainActor
final class PesterTest: ObservableObject {
    static let shared = PesterTest()
    private static let batchIDs = (1...20).map { "pester.numbered-test.\($0)" }
    private static let allIDs = batchIDs + ["pester.repeating-test", "pester.notification-test"]
    private let generationKey = "pester.test.generation"
    private let logKey = "pester.test.events"
    @Published private(set) var busy = false
    @Published private(set) var active = false
    @Published private(set) var status = "Ready for a numbered test: 20 alerts, one minute apart."
    @Published private(set) var showSettings = false
    @Published private(set) var events: [String] = UserDefaults.standard.stringArray(forKey: "pester.test.events") ?? []
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

    func refresh() async {
        await serially { await self.updateStatus() }
    }

    private func updateStatus() async {
        let requests = await center.pendingNotificationRequests().filter { Self.allIDs.contains($0.identifier) }
        active = !requests.isEmpty
        let dates = requests.compactMap { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() }.sorted()
        if let next = dates.first, let end = dates.last {
            status = "\(requests.count) pending. Next expected: \(next.formatted(date: .omitted, time: .standard)). Last scheduled: \(end.formatted(date: .omitted, time: .standard))."
            if requests.contains(where: { $0.identifier == "pester.repeating-test" }) {
                status = "Previous repeating test is active. Complete it before starting a numbered batch."
            }
        } else {
            status = "No test alerts remain pending. The batch may have ended or been completed; this does not confirm delivery."
        }
    }

    func start(snoozing: Bool = false) async {
        await serially { await self.installBatch(snoozing: snoozing) }
    }

    private func installBatch(snoozing: Bool) async {
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
            center.removePendingNotificationRequests(withIdentifiers: Self.allIDs)
            center.removeDeliveredNotifications(withIdentifiers: Self.allIDs)
            replacing = true
            UserDefaults.standard.set(generation, forKey: generationKey)
            let start = Date()
            for (index, id) in Self.batchIDs.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = snoozing ? "After snooze · Pester \(index + 1)" : "Pester \(index + 1)"
                content.body = snoozing
                    ? "Your 3-minute snooze has ended. Alert \(index + 1) of 20; one minute apart."
                    : "Test alert \(index + 1) of 20. Complete to stop, or snooze for 3 minutes."
                content.sound = .default
                content.categoryIdentifier = "pester.test"
                content.threadIdentifier = "pester.test"
                content.userInfo = ["generation": generation]
                let fireDate = start.addingTimeInterval(TimeInterval((snoozing ? 180 : 60) + index * 60))
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fireDate.timeIntervalSinceNow), repeats: false)
                try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
            await updateStatus()
            record(snoozing ? "Snoozed 3 minutes; replaced batch, numbering restarts at 1." : "Started 20 numbered alerts, first in 1 minute.")
            status = (snoozing ? "Snoozed for 3 minutes. " : "Batch scheduled. ") + status
            if settings.alertSetting != .enabled || settings.authorizationStatus == .provisional {
                status += " Alerts may be quiet or disabled; check Settings."
                showSettings = true
            }
        } catch {
            if replacing {
                center.removePendingNotificationRequests(withIdentifiers: Self.allIDs)
                UserDefaults.standard.removeObject(forKey: generationKey)
            }
            await updateStatus()
            status = "Could not schedule: \(error.localizedDescription). " + (replacing ? "Partial batch cancelled. " : "") + status
            record(status)
        }
    }

    func complete() async {
        await serially { await self.cancelBatch() }
    }

    private func cancelBatch() async {
        center.removePendingNotificationRequests(withIdentifiers: Self.allIDs)
        center.removeDeliveredNotifications(withIdentifiers: Self.allIDs)
        UserDefaults.standard.removeObject(forKey: generationKey)
        await updateStatus()
        status = active ? "A test is still pending. Try Complete again." : "Completed. No test alerts remain scheduled."
        record(status)
    }

    func handle(_ response: UNNotificationResponse) async {
        await serially {
            let request = response.notification.request
            guard Self.allIDs.contains(request.identifier) else { return }
            let action = response.actionIdentifier
            let name: String
            switch action {
            case "complete": name = "Complete selected"
            case "snooze": name = "Snooze selected"
            case UNNotificationDefaultActionIdentifier: name = "Opened app from notification"
            case UNNotificationDismissActionIdentifier: name = "Explicit dismissal reported by iOS"
            default: name = "Other response: \(action)"
            }
            self.record("\(name): \(request.content.title)")
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
        }
    }
}
