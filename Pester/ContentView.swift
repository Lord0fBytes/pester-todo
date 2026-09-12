import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = TaskStore.shared
    @State private var showingNewTask = false
    @State private var selectedTask: PesterTask?
    @State private var taskToDelete: PesterTask?

    private var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = Int(info["CFBundleVersion"] as? String ?? "0") ?? 0
        return "\(version)-\(String(format: "%04d", build))"
    }

    private var inboxSections: [InboxSection] {
        InboxSection.Kind.allCases.compactMap { kind in
            let matchingTasks = store.tasks
                .filter { kind.includes($0) }
                .sorted {
                    let firstPriority = kind.sortPriority(for: $0)
                    let secondPriority = kind.sortPriority(for: $1)
                    if firstPriority != secondPriority { return firstPriority < secondPriority }
                    let firstDate = kind.sortDate(for: $0)
                    let secondDate = kind.sortDate(for: $1)
                    if firstDate != secondDate { return firstDate < secondDate }
                    if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                    return $0.id.uuidString < $1.id.uuidString
                }
            return matchingTasks.isEmpty ? nil : InboxSection(kind: kind, tasks: matchingTasks)
        }
    }

    private var completedTasks: [PesterTask] {
        store.tasks
            .filter { $0.state == .completed }
            .sorted {
                let firstDate = $0.completedAt ?? $0.updatedAt
                let secondDate = $1.completedAt ?? $1.updatedAt
                if firstDate != secondDate { return firstDate > secondDate }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section {
                        Text("Choose a task to view its schedule, durations, actions, and activity.")
                            .foregroundStyle(.secondary)
                    }
                    if store.tasks.isEmpty {
                        Section("Tasks") {
                            VStack(spacing: 8) {
                                Label("No tasks", systemImage: "checklist")
                                    .font(.headline)
                                Text("Tap Add to create your first task.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                    } else {
                        ForEach(inboxSections) { section in
                            Section {
                                ForEach(section.tasks) { task in
                                Button {
                                    selectedTask = task
                                    } label: {
                                        TaskRow(task: task, tint: section.kind.rowTint(for: task))
                                    }
                                    .buttonStyle(.plain)
                                    .contentShape(Rectangle())
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
                            } header: {
                                Text(section.kind.title)
                            }
                        }
                        if !completedTasks.isEmpty {
                            Section {
                                NavigationLink {
                                    CompletedTasksView(store: store)
                                } label: {
                                    Label {
                                        HStack {
                                            Text("Completed")
                                            Spacer()
                                            Text("\(completedTasks.count)")
                                                .foregroundStyle(.secondary)
                                        }
                                    } icon: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.secondary)
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
            .sheet(isPresented: $showingNewTask) {
                TaskEditorSheet(store: store)
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailsSheet(task: task, store: store)
                    .presentationDetents([.height(340), .large])
                    .presentationDragIndicator(.visible)
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
            .task(id: scenePhase) {
                switch scenePhase {
                case .active:
                    await becameActive()
                case .background:
                    await becameBackground()
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

private struct InboxSection: Identifiable {
    enum Kind: Int, CaseIterable, Identifiable {
        case pestering
        case upcoming

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .pestering: "Pestering"
            case .upcoming: "Upcoming"
            }
        }

        @MainActor
        func includes(_ task: PesterTask) -> Bool {
            switch self {
            case .pestering:
                return task.state == .overdue || task.state == .active || task.state == .snoozed
            case .upcoming:
                return task.state == .upcoming
            }
        }

        @MainActor
        func sortPriority(for task: PesterTask) -> Int {
            guard self == .pestering else { return 0 }
            switch task.state {
            case .overdue: return 0
            case .active: return 1
            case .snoozed: return 2
            default: return 3
            }
        }

        @MainActor
        func sortDate(for task: PesterTask) -> Date {
            switch self {
            case .pestering:
                if task.state == .snoozed {
                    return task.snoozedUntil ?? task.nextPesterAt ?? .distantFuture
                }
                return task.nextPesterAt ?? .distantFuture
            case .upcoming:
                return task.nextPesterAt ?? task.scheduledStart ?? task.dueAt ?? task.updatedAt
            }
        }

        @MainActor
        func rowTint(for task: PesterTask) -> Color {
            guard self == .upcoming else { return task.state.tint }
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
            let nextDate = task.nextPesterAt ?? task.scheduledStart ?? task.dueAt ?? .distantFuture
            return nextDate < tomorrow ? .green : .blue
        }
    }

    let kind: Kind
    let tasks: [PesterTask]
    var id: Kind { kind }
}

private struct CompletedTasksView: View {
    @ObservedObject var store: TaskStore
    @State private var selectedTask: PesterTask?

    private var tasks: [PesterTask] {
        store.tasks
            .filter { $0.state == .completed }
            .sorted {
                let firstDate = $0.completedAt ?? $0.updatedAt
                let secondDate = $1.completedAt ?? $1.updatedAt
                if firstDate != secondDate { return firstDate > secondDate }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    var body: some View {
        List {
            if tasks.isEmpty {
                Text("No completed tasks")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tasks) { task in
                    Button {
                        selectedTask = task
                    } label: {
                        TaskRow(task: task)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Completed")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedTask) { task in
            TaskDetailsSheet(task: task, store: store)
                .presentationDetents([.height(340), .large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct TaskRow: View {
    @ObservedObject var task: PesterTask
    var tint: Color? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.state.symbolName)
                .font(.title3)
                .foregroundStyle(tint ?? task.state.tint)
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
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TaskDetailsSheet: View {
    private enum EditorMode: Equatable {
        case title
        case dueDate
    }

    @ObservedObject var task: PesterTask
    @ObservedObject var store: TaskStore
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleIsFocused: Bool
    @State private var editorMode: EditorMode?
    @State private var titleDraft: String
    @State private var dueDateDraft: Date
    @State private var pesterMinutes: Int
    @State private var snoozeMinutes: Int
    @State private var saving = false
    @State private var confirmingDelete = false

    init(task: PesterTask, store: TaskStore) {
        self.task = task
        self.store = store
        _titleDraft = State(initialValue: task.title)
        _dueDateDraft = State(initialValue: task.dueAt ?? task.scheduledStart ?? Date().addingTimeInterval(5 * 60))
        _pesterMinutes = State(initialValue: task.pesterMinutes)
        _snoozeMinutes = State(initialValue: task.snoozeMinutes)
    }

    private var editorActionEnabled: Bool {
        guard !task.busy, !saving else { return false }
        switch editorMode {
        case .title:
            return !titleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .dueDate:
            return dueDateDraft > Date()
        case nil:
            return true
        }
    }

    private var canAct: Bool {
        task.state != .notScheduled && task.state != .completed
    }

    @ViewBuilder
    private var dueDateEditor: some View {
        Section {
            DatePicker(
                "Date",
                selection: $dueDateDraft,
                in: Date()...,
                displayedComponents: .date
            )
            DatePicker(
                "Time",
                selection: $dueDateDraft,
                in: Date()...,
                displayedComponents: .hourAndMinute
            )
        } header: {
            Text("Choose a new due date")
        } footer: {
            Text("Setting a new due time replaces this task’s current notification schedule.")
        }
    }

    @ViewBuilder
    private var titleEditor: some View {
        Section {
            TextField("Task title", text: $titleDraft)
                .font(.title2.weight(.semibold))
                .textInputAutocapitalization(.sentences)
                .focused($titleIsFocused)
                .submitLabel(.done)
                .onSubmit { saveTitle() }
        } footer: {
            Text("Renaming a task preserves its current alert times and pester count.")
        }
    }

    private var taskSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { beginTitleEditing() } label: {
                Text(task.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit title, \(task.title)")

            Button { beginDueDateEditing() } label: {
                Text(task.dueAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unavailable")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(uiColor: .secondarySystemFill))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit due date, \(task.dueAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unavailable")")
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(uiColor: .separator), lineWidth: 1)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            if canAct {
                TaskIconAction(title: "Complete", systemImage: "checkmark", tint: .green, action: completeTask)
                Spacer(minLength: 0)
                TaskIconAction(title: "Snooze", systemImage: "moon.zzz", tint: .blue, action: snoozeTask)
                Spacer(minLength: 0)
            }
            TaskIconAction(title: "Delete", systemImage: "trash", tint: .red) {
                confirmingDelete = true
            }
            Spacer(minLength: 0)
            TaskIconAction(title: "Close", systemImage: "xmark", tint: .secondary, action: dismiss.callAsFunction)
            Spacer(minLength: 0)
        }
        .disabled(task.busy || saving)
    }

    private var durationBar: some View {
        HStack(spacing: 0) {
            TaskDurationControl(
                title: "Pester every",
                systemImage: "bell.badge",
                value: pesterMinutes,
                selection: $pesterMinutes
            )
            TaskDurationControl(
                title: "Snooze for",
                systemImage: "timer",
                value: snoozeMinutes,
                selection: $snoozeMinutes
            )
        }
        .disabled(task.busy || saving)
        .onChange(of: pesterMinutes) { _ in saveDurations() }
        .onChange(of: snoozeMinutes) { _ in saveDurations() }
    }

    @ViewBuilder
    private var statusSection: some View {
        if task.busy || saving || task.showSettings {
            VStack(spacing: 12) {
                if task.busy || saving {
                    ProgressView("Updating…")
                }
                if task.showSettings {
                    Button("Open notification settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .frame(minHeight: 44)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if editorMode == .dueDate {
                    Form { dueDateEditor }
                } else if editorMode == .title {
                    Form { titleEditor }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            actionBar
                            taskSummary
                            if task.state != .completed {
                                durationBar
                            }
                            statusSection
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 28)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle(editorMode == .dueDate ? "Reschedule" : (editorMode == .title ? "Edit Title" : ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if editorMode != nil {
                        Button("Cancel") { cancelEditing() }
                            .disabled(task.busy || saving)
                    }
                }
                if editorMode != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(editorMode == .dueDate ? "Set" : "Save") {
                            switch editorMode {
                            case .title: saveTitle()
                            case .dueDate: saveDueDate()
                            case nil: break
                            }
                        }
                        .disabled(!editorActionEnabled)
                    }
                }
            }
            .interactiveDismissDisabled(editorMode != nil)
            .onChange(of: editorMode) { mode in
                titleIsFocused = mode == .title
            }
            .confirmationDialog("Delete this task?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete task", role: .destructive) {
                    Task {
                        await store.delete(task)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The task and all of its pending and delivered notifications will be removed.")
            }
        }
    }

    private func beginTitleEditing() {
        titleDraft = task.title
        editorMode = .title
    }

    private func beginDueDateEditing() {
        let earliest = Date().addingTimeInterval(60)
        dueDateDraft = max(task.dueAt ?? task.scheduledStart ?? earliest, earliest)
        editorMode = .dueDate
    }

    private func cancelEditing() {
        titleDraft = task.title
        dueDateDraft = task.dueAt ?? task.scheduledStart ?? dueDateDraft
        editorMode = nil
    }

    private func saveTitle() {
        guard editorMode == .title, editorActionEnabled, let dueAt = task.dueAt else { return }
        saving = true
        Task {
            await store.update(
                task,
                title: titleDraft,
                dueAt: dueAt,
                pesterMinutes: task.pesterMinutes,
                snoozeMinutes: task.snoozeMinutes
            )
            titleDraft = task.title
            saving = false
            editorMode = nil
        }
    }

    private func saveDueDate() {
        guard editorMode == .dueDate, editorActionEnabled else { return }
        saving = true
        Task {
            await store.update(
                task,
                title: task.title,
                dueAt: dueDateDraft,
                pesterMinutes: task.pesterMinutes,
                snoozeMinutes: task.snoozeMinutes
            )
            dueDateDraft = task.dueAt ?? dueDateDraft
            saving = false
            editorMode = nil
        }
    }

    private func saveDurations() {
        guard !saving,
              pesterMinutes != task.pesterMinutes || snoozeMinutes != task.snoozeMinutes else { return }
        let newPesterMinutes = pesterMinutes
        let newSnoozeMinutes = snoozeMinutes
        saving = true
        Task {
            await task.apply(interval: newPesterMinutes, snooze: newSnoozeMinutes)
            pesterMinutes = task.pesterMinutes
            snoozeMinutes = task.snoozeMinutes
            saving = false
        }
    }

    private func snoozeTask() {
        Task {
            await task.start(snoozing: true)
            dismiss()
        }
    }

    private func completeTask() {
        Task {
            await task.complete()
            dismiss()
        }
    }
}

private struct TaskIconAction: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 53, height: 53)
                .overlay {
                    Circle()
                        .stroke(Color(uiColor: .separator), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct TaskDurationControl: View {
    private static let options = [1, 2, 3, 4, 5, 10, 15, 20, 30, 45, 60]

    let title: String
    let systemImage: String
    let value: Int
    @Binding var selection: Int

    var body: some View {
        Menu {
            Section(title) {
                ForEach(Self.options, id: \.self) { minutes in
                    Button(minutes == 1 ? "1 minute" : "\(minutes) minutes") {
                        selection = minutes
                    }
                }
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.14), in: Circle())
                Text(value == 1 ? "1 min" : "\(value) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, minHeight: 68)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("\(title), \(value == 1 ? "1 minute" : "\(value) minutes")")
    }
}

private struct DurationPicker: View {
    private static let options = [1, 2, 3, 4, 5, 10, 15, 20, 30, 45, 60]

    let title: String
    @Binding var selection: Int

    init(_ title: String, selection: Binding<Int>) {
        self.title = title
        _selection = selection
    }

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(Self.options, id: \.self) { minutes in
                Text(minutes == 1 ? "1 minute" : "\(minutes) minutes")
                    .tag(minutes)
            }
        }
        .pickerStyle(.menu)
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
                    DurationPicker("Pester every", selection: $pesterMinutes)
                    DurationPicker("Snooze for", selection: $snoozeMinutes)
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
