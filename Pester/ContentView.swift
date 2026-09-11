import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = TaskStore.shared
    @State private var showingNewTask = false
    @State private var taskToDelete: PesterTask?

    private var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = Int(info["CFBundleVersion"] as? String ?? "0") ?? 0
        return "\(version)-\(String(format: "%04d", build))"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section {
                        Text("Choose a task to view its schedule, durations, actions, and activity.")
                            .foregroundStyle(.secondary)
                    }
                    Section("Tasks") {
                        if store.tasks.isEmpty {
                            VStack(spacing: 8) {
                                Label("No tasks", systemImage: "checklist")
                                    .font(.headline)
                                Text("Tap Add to create your first task.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else {
                            ForEach(store.tasks) { task in
                                NavigationLink(value: task.id) { TaskRow(task: task) }
                                    .listRowBackground(
                                        taskToDelete?.id == task.id
                                            ? Color.red.opacity(0.12)
                                            : Color(uiColor: .secondarySystemGroupedBackground)
                                    )
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        if task.active {
                                            Button {
                                                Task { await task.complete() }
                                            } label: {
                                                Label("Complete", systemImage: "checkmark")
                                            }
                                            .tint(.green)
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button {
                                            taskToDelete = task
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                        if task.active {
                                            Button {
                                                Task { await task.start(snoozing: true) }
                                            } label: {
                                                Label("Snooze", systemImage: "moon.zzz")
                                            }
                                            .tint(.indigo)
                                        }
                                    }
                            }
                        }
                    }
                }

                Text(appVersion)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .accessibilityLabel("App version \(appVersion)")
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Pester")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewTask = true
                    } label: {
                        Label("Add task", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { taskID in
                if let task = store.tasks.first(where: { $0.id == taskID }) {
                    TaskDetailView(task: task, store: store)
                }
            }
            .sheet(isPresented: $showingNewTask) {
                TaskEditorSheet(store: store)
            }
            .confirmationDialog(
                "Delete this task?",
                isPresented: Binding(
                    get: { taskToDelete != nil },
                    set: { if !$0 { taskToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete task", role: .destructive) {
                    guard let task = taskToDelete else { return }
                    Task { await store.delete(task) }
                    taskToDelete = nil
                }
                Button("Cancel", role: .cancel) { taskToDelete = nil }
            } message: {
                Text("The task and all of its pending and delivered notifications will be removed.")
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
        for task in store.tasks { await task.appBecameActive() }
    }

    private func becameBackground() async {
        for task in store.tasks { await task.appBecameBackground() }
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
                if task.state == .snoozed, let snoozedUntil = task.snoozedUntil ?? task.scheduledStart {
                    Text("Snoozed until: \(snoozedUntil.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let next = task.nextPesterAt {
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
    @ObservedObject var store: TaskStore
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var interval = 1
    @State private var snooze = 3
    @State private var futureDate = Date().addingTimeInterval(5 * 60)
    @State private var showingEditor = false
    @State private var confirmingDelete = false

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
                if task.state == .snoozed, let snoozedUntil = task.snoozedUntil ?? task.scheduledStart {
                    LabeledContent("Snoozed until") {
                        Text(snoozedUntil.formatted(date: .abbreviated, time: .shortened))
                            .multilineTextAlignment(.trailing)
                    }
                } else if let next = task.nextPesterAt {
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
            }

            Section("Manage Task") {
                Button("Delete task", role: .destructive) {
                    confirmingDelete = true
                }
                .frame(minHeight: 44)
                .disabled(task.busy)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            TaskEditorSheet(store: store, task: task)
        }
        .confirmationDialog("Delete \(task.title)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete task", role: .destructive) {
                Task {
                    await store.delete(task)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its pending and delivered notifications will also be removed.")
        }
        .onAppear {
            interval = task.pesterMinutes
            snooze = task.snoozeMinutes
            if let scheduledStart = task.scheduledStart, scheduledStart > Date() {
                futureDate = scheduledStart
            }
        }
    }
}

private struct TaskEditorSheet: View {
    @ObservedObject var store: TaskStore
    let task: PesterTask?
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var dueAt: Date
    @State private var pesterMinutes: Int
    @State private var snoozeMinutes: Int
    @State private var saving = false

    init(store: TaskStore, task: PesterTask? = nil) {
        self.store = store
        self.task = task
        let earliest = Date().addingTimeInterval(60)
        _title = State(initialValue: task?.title ?? "")
        _dueAt = State(initialValue: max(task?.dueAt ?? task?.scheduledStart ?? Date().addingTimeInterval(5 * 60), earliest))
        _pesterMinutes = State(initialValue: task?.pesterMinutes ?? 5)
        _snoozeMinutes = State(initialValue: task?.snoozeMinutes ?? 15)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && dueAt > Date() && !saving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                    DatePicker(
                        "Due",
                        selection: $dueAt,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section {
                    Stepper("Every \(pesterMinutes) min", value: $pesterMinutes, in: 1...60)
                    Stepper("Snooze for \(snoozeMinutes) min", value: $snoozeMinutes, in: 1...60)
                } header: {
                    Text("Pestering")
                } footer: {
                    Text("Pester schedules up to \(PesterTask.batchCount) alerts beginning at the due time.")
                }

                if saving {
                    Section { ProgressView("Saving task…") }
                }
            }
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        saving = true
        Task {
            if let task {
                await store.update(
                    task,
                    title: title,
                    dueAt: dueAt,
                    pesterMinutes: pesterMinutes,
                    snoozeMinutes: snoozeMinutes
                )
            } else {
                await store.create(
                    title: title,
                    dueAt: dueAt,
                    pesterMinutes: pesterMinutes,
                    snoozeMinutes: snoozeMinutes
                )
            }
            dismiss()
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
