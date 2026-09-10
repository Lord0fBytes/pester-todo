import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    private var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = Int(info["CFBundleVersion"] as? String ?? "0") ?? 0
        return "\(version)-\(String(format: "%04d", build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Two independent reminders. Each schedules 8 alerts, then stops. Notification text shows the pester count for debugging. Apply changes restarts only that reminder’s active countdown.")
                }
                Section("Build") {
                    Text(appVersion)
                        .font(.caption)
                        .monospacedDigit()
                        .accessibilityLabel("App version \(appVersion)")
                }
                ForEach(PesterTest.tests, id: \.id) { test in
                    ReminderControls(test: test)
                }
            }
            .navigationTitle("Pester")
            .task { await becameActive() }
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active:
                    Task { await becameActive() }
                case .background:
                    Task { await becameBackground() }
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func becameActive() async {
        for test in PesterTest.tests { await test.appBecameActive() }
    }

    private func becameBackground() async {
        for test in PesterTest.tests { await test.appBecameBackground() }
    }
}

private struct ReminderControls: View {
    @ObservedObject var test: PesterTest
    @Environment(\.openURL) private var openURL
    @State private var interval = 1
    @State private var snooze = 3

    private var changed: Bool { interval != test.pesterMinutes || snooze != test.snoozeMinutes }

    var body: some View {
        Section(test.name) {
            Stepper("Pester every \(interval) min", value: $interval, in: 1...60)
                .disabled(test.busy)
            Stepper("Snooze for \(snooze) min", value: $snooze, in: 1...60)
                .disabled(test.busy)
            Button(test.active ? "Apply changes & restart countdown" : "Save durations") {
                Task { await test.apply(interval: interval, snooze: snooze) }
            }
            .frame(minHeight: 44)
            .disabled(test.busy || !changed)
            Button("Start \(test.name)") { Task { await test.start() } }
                .frame(minHeight: 44)
                .disabled(test.busy || test.active || changed)
            Button("Snooze \(test.snoozeMinutes) min") { Task { await test.start(snoozing: true) } }
                .frame(minHeight: 44)
                .disabled(test.busy || !test.active || changed)
            Button("Complete \(test.name)") { Task { await test.complete() } }
                .frame(minHeight: 44)
                .disabled(test.busy)
            if changed { Text("Save or apply the durations before starting or snoozing.") }
            if test.busy { ProgressView("Updating…") }
            Text(test.status)
            if test.showSettings {
                Button("Open notification settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                .frame(minHeight: 44)
            }
            DisclosureGroup("Interaction log") {
                Text("Local events only; background delivery and reading an alert are not reported.")
                ForEach(Array(test.events.enumerated()), id: \.offset) { entry in
                    Text(entry.element).font(.caption).textSelection(.enabled)
                }
            }
        }
        .onAppear {
            interval = test.pesterMinutes
            snooze = test.snoozeMinutes
        }
    }
}
