import SwiftUI
import SwiftData

@main
struct FatigueTrackerApp: App {
    let container: ModelContainer = {
        do {
            let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
            let config = ModelConfiguration(isStoredInMemoryOnly: isUITesting)
            return try ModelContainer(for: FatigueEntry.self, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
