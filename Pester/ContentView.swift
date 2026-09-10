import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject private var test = PesterTest.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section("Pestering test") {
                    Text("20 separate alerts with identical text, one minute apart. This test stops after the batch ends; it does not repeat indefinitely.")
                    Button("Start same-text test") {
                        Task { await test.start() }
                    }
                    .frame(minHeight: 44)
                    .disabled(test.busy || test.active)
                    Button("Snooze 3 minutes") {
                        Task { await test.start(snoozing: true) }
                    }
                    .frame(minHeight: 44)
                    .disabled(test.busy || !test.active)
                    Button("Complete") {
                        Task { await test.complete() }
                    }
                    .frame(minHeight: 44)
                    .disabled(test.busy)
                }
                Section("Status") {
                    if test.busy { ProgressView("Updating notification schedule…") }
                    Text(test.status)
                    if test.showSettings {
                        Button("Open notification settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                openURL(url)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }
                Section("On your Lock Screen") {
                    Text("Touch and hold the notification to reveal Complete and Snooze. Swiping it away does not stop pestering.")
                    Text("Snooze clears the current alerts and schedules a fresh batch starting in 3 minutes, then every minute. The title and body stay the same, including after snooze.")
                }
                Section("Interaction log — newest first") {
                    Text("Saved on this phone. Taps and explicit dismissals may be logged; seeing or reading an alert is not reported. Background delivery is not a log event.")
                    if test.events.isEmpty { Text("No interactions recorded yet.") }
                    ForEach(Array(test.events.enumerated()), id: \.offset) { entry in
                        Text(entry.element)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Pester")
            .task { await test.refresh() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { Task { await test.refresh() } }
            }
        }
    }
}
