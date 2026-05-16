import SwiftUI
import SwiftData

@main
struct FatigueTrackerApp: App {
    let container: ModelContainer = {
        do {
            return try ModelContainer(for: FatigueEntry.self)
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
