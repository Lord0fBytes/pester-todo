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
            List {
                Section {
                    Text("Choose a task to view its schedule, durations, actions, and activity.")
                        .foregroundStyle(.secondary)
                }
                Section("Tasks") {
                    ForEach(PesterTask.tasks) { task in
                        NavigationLink(value: task.id) { TaskRow(task: task) }
                    }
                }
                Section("Build") {
                    Text(appVersion)
                        .font(.caption)
                        .monospacedDigit()
                        .accessibilityLabel("App version \(appVersion)")
                }
            }
            .navigationTitle("Pester")
            .navigationDestination(for: UUID.self) { taskID in
                if let task = PesterTask.tasks.first(where: { $0.id == taskID }) {
                    TaskDetailView(task: task)
                }
            }
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
        for task in PesterTask.tasks { await task.appBecameActive() }
    }

    private func becameBackground() async {
        for task in PesterTask.tasks { await task.appBecameBackground() }
    }
}

private struct TaskRow: View {
    @ObservedObject var task: PesterTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.state.symbolName)
                .font(.title3)
                .foregroundStyle(task.state.tint)
                .frame(width: 32, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title).font(.headline)
                Text(task.state.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let next = task.nextPesterAt {
                    Text("Next: \(next.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TaskDetailView: View {
    @ObservedObject var task: PesterTask
    @Environment(\.openURL) private var openURL
    @State private var interval = 1
    @State private var snooze = 3
    @State private var futureDate = Date().addingTimeInterval(5 * 60)

    private var changed: Bool {
        interval != task.pesterMinutes || snooze != task.snoozeMinutes
    }

    private var canComplete: Bool {
        task.state != .notScheduled && task.state != .completed
    }

    var body: some View {
        Form {
            Section("Task") {
                LabeledContent("Title", value: task.title)
                LabeledContent("State", value: task.state.rawValue)
                LabeledContent("Pester count", value: "\(task.pesterCount)/\(task.maxPesterCount)")
                if let next = task.nextPesterAt {
                    LabeledContent("Next pester") {
                        Text(next.formatted(date: .abbreviated, time: .shortened))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Section("Schedule") {
                DatePicker(
                    "Date and time",
                    selection: $futureDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .disabled(task.busy)
                if let scheduledStart = task.scheduledStart, scheduledStart > Date() {
                    LabeledContent("Scheduled for") {
                        Text(scheduledStart.formatted(date: .abbreviated, time: .shortened))
                            .multilineTextAlignment(.trailing)
                    }
                }
                Button(task.active ? "Reschedule for selected time" : "Schedule for selected time") {
                    Task { await task.schedule(at: futureDate) }
                }
                .frame(minHeight: 44)
                .disabled(task.busy || changed || futureDate <= Date())
            }

            Section("Durations") {
                Stepper("Pester every \(interval) min", value: $interval, in: 1...60)
                    .disabled(task.busy)
                Stepper("Snooze for \(snooze) min", value: $snooze, in: 1...60)
                    .disabled(task.busy)
                Button(task.active ? "Apply changes and restart countdown" : "Save durations") {
                    Task { await task.apply(interval: interval, snooze: snooze) }
                }
                .frame(minHeight: 44)
                .disabled(task.busy || !changed)
                if changed {
                    Text("Save the durations before scheduling, starting, or snoozing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Actions") {
                Button("Start now") { Task { await task.start() } }
                    .frame(minHeight: 44)
                    .disabled(task.busy || task.active || changed)
                Button("Snooze for \(task.snoozeMinutes) min") { Task { await task.start(snoozing: true) } }
                    .frame(minHeight: 44)
                    .disabled(task.busy || !task.active || changed)
                Button("Complete task") { Task { await task.complete() } }
                    .frame(minHeight: 44)
                    .disabled(task.busy || !canComplete)
                if task.active {
                    Button("Delete schedule", role: .destructive) {
                        Task { await task.deleteSchedule() }
                    }
                    .frame(minHeight: 44)
                    .disabled(task.busy)
                }
            }

            Section("Status") {
                if task.busy { ProgressView("Updating…") }
                Text(task.status)
                if task.showSettings {
                    Button("Open notification settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .frame(minHeight: 44)
                }
            }

            Section("Diagnostics") {
                LabeledContent("Task ID") {
                    Text(task.id.uuidString)
                        .font(.caption)
                        .monospaced()
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                }
                DisclosureGroup("Interaction log") {
                    Text("Local events only; background delivery and reading an alert are not reported.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(Array(task.events.enumerated()), id: \.offset) { entry in
                        Text(entry.element)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle(task.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            interval = task.pesterMinutes
            snooze = task.snoozeMinutes
            if let scheduledStart = task.scheduledStart, scheduledStart > Date() {
                futureDate = scheduledStart
            }
        }
    }
}

private extension PesterTask.TaskState {
    var symbolName: String {
        switch self {
        case .notScheduled: "circle.dashed"
        case .upcoming: "clock"
        case .active: "bell.badge"
        case .snoozed: "moon.zzz"
        case .overdue: "exclamationmark.circle"
        case .completed: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .notScheduled: .secondary
        case .upcoming: .blue
        case .active: .orange
        case .snoozed: .indigo
        case .overdue: .red
        case .completed: .green
        }
    }
}
