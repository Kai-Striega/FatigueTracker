import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]
    
    @State private var showingResetAlert = false
    
    private var settings: AppSettings? { settingsList.first }
    
    var body: some View {
        NavigationStack {
            Form {
                if let settings {
                    Section("Prompt frequency") {
                        Stepper(value: Binding(
                            get: { settings.intervalMinutes },
                            set: { newValue in
                                settings.intervalMinutes = newValue
                                save()
                                reschedule()
                            }
                        ), in: 15...240, step: 15) {
                            HStack {
                                Text("Every")
                                Spacer()
                                Text("\(settings.intervalMinutes) min")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Section("Active hours") {
                        Picker("Start", selection: Binding(
                            get: { settings.activeStartHour },
                            set: { newValue in
                                settings.activeStartHour = newValue
                                save()
                                reschedule()
                            }
                        )) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        
                        Picker("End", selection: Binding(
                            get: { settings.activeEndHour },
                            set: { newValue in
                                settings.activeEndHour = newValue
                                save()
                                reschedule()
                            }
                        )) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                    }
                    
                    Section("Missed timeout") {
                        Stepper(value: Binding(
                            get: { settings.missedTimeoutMinutes },
                            set: { newValue in
                                settings.missedTimeoutMinutes = newValue
                                save()
                            }
                        ), in: 5...60, step: 5) {
                            HStack {
                                Text("Mark missed after")
                                Spacer()
                                Text("\(settings.missedTimeoutMinutes) min")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Section {
                        Button("Reschedule now") {
                            reschedule()
                        }
                    } footer: {
                        Text("Notifications are scheduled when the app opens. Use this if you change settings and want to apply immediately.")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private func save() {
        try? modelContext.save()
    }
    
    private func reschedule() {
        guard let settings else { return }
        let context = modelContext
        Task { @MainActor in
            await NotificationManager.shared.scheduleToday(settings: settings,
                                                            context: context)
        }
    }
    
    private func formatHour(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(.dateTime.hour())
    }
}
