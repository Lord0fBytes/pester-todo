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
                    Text("Schedule either reminder for later or start it after leaving Pester. Each reminder sends up to 8 alerts and keeps its own schedule.")
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
    @State private var futureDate = Date().addingTimeInterval(5 * 60)

    private var changed: Bool { interval != test.pesterMinutes || snooze != test.snoozeMinutes }

    var body: some View {
        Section(test.name) {
            Stepper("Pester every \(interval) min", value: $interval, in: 1...60)
                .disabled(test.busy)
            Stepper("Snooze for \(snooze) min", value: $snooze, in: 1...60)
                .disabled(test.busy)
            DatePicker(
                "Scheduled time",
                selection: $futureDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .disabled(test.busy)
            if let scheduledStart = test.scheduledStart, scheduledStart > Date() {
                LabeledContent("Upcoming") {
                    Text(scheduledStart.formatted(date: .abbreviated, time: .shortened))
                        .multilineTextAlignment(.trailing)
                }
            }
            Button(test.active ? "Apply changes & restart countdown" : "Save durations") {
                Task { await test.apply(interval: interval, snooze: snooze) }
            }
            .frame(minHeight: 44)
            .disabled(test.busy || !changed)
            Button("Start \(test.name)") { Task { await test.start() } }
                .frame(minHeight: 44)
                .disabled(test.busy || test.active || changed)
            Button(test.active ? "Reschedule for selected time" : "Schedule for selected time") {
                Task { await test.schedule(at: futureDate) }
            }
            .frame(minHeight: 44)
            .disabled(test.busy || changed || futureDate <= Date())
            Button("Snooze \(test.snoozeMinutes) min") { Task { await test.start(snoozing: true) } }
                .frame(minHeight: 44)
                .disabled(test.busy || !test.active || changed)
            Button("Complete \(test.name)") { Task { await test.complete() } }
                .frame(minHeight: 44)
                .disabled(test.busy)
            if test.active {
                Button("Delete schedule", role: .destructive) {
                    Task { await test.deleteSchedule() }
                }
                .frame(minHeight: 44)
                .disabled(test.busy)
            }
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
            if let scheduledStart = test.scheduledStart, scheduledStart > Date() {
                futureDate = scheduledStart
            }
        }
    }
}
