import Combine
import SwiftUI
import SwiftData
import UserNotifications

@main
struct FatigueTrackerApp: App {
    @StateObject private var notificationCoordinator = NotificationCoordinator()
    
    let container: ModelContainer = {
        do {
            return try ModelContainer(for: FatigueEntry.self, AppSettings.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Register categories and set delegate at launch so we don't miss a
        // notification response that arrives before the first view appears.
        NotificationManager.shared.registerCategories()
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationCoordinator)
                .onAppear {
                    NotificationManager.shared.coordinator = notificationCoordinator
                }
        }
        .modelContainer(container)
    }
}

/// Bridges notification taps into SwiftUI state so the entry sheet can appear.
final class NotificationCoordinator: ObservableObject {
    @Published var pendingPrompt: PendingPrompt?
}

struct PendingPrompt: Identifiable, Equatable {
    let id = UUID()
    let promptID: String
    let scheduledAt: Date
    let preFilledSeverity: Int?
}
