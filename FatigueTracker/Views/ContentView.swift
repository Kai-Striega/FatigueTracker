import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var coordinator: NotificationCoordinator
    @Query private var settingsList: [AppSettings]
    
    var body: some View {
        TabView {
            HistoryView()
                .tabItem { Label("Log", systemImage: "list.bullet") }
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .onAppear {
            ensureSettingsExist()
            Task { await onActivate() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await onActivate() }
            }
        }
        .sheet(item: $coordinator.pendingPrompt) { prompt in
            EntryFormView(mode: .respondingToPrompt(prompt))
        }
    }
    
    private func ensureSettingsExist() {
        if settingsList.isEmpty {
            modelContext.insert(AppSettings())
            try? modelContext.save()
        }
    }
    
    /// Called on first appear and whenever the app comes to the foreground.
    /// Sweeps stale pending entries to missed, then re-schedules today's prompts.
    @MainActor
    private func onActivate() async {
        guard let settings = settingsList.first else { return }
        MissedEntrySweeper.sweep(settings: settings, context: modelContext)
        
        let authorized = await NotificationManager.shared.requestAuthorization()
        guard authorized else { return }
        await NotificationManager.shared.scheduleToday(settings: settings,
                                                        context: modelContext)
    }
}
