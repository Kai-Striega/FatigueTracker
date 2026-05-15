import Foundation
import UserNotifications
import SwiftData

/// Handles all notification scheduling and response handling.
/// Notifications include 5 severity action buttons; tapping one records severity
/// and deep-links into the app so the user can type the activity description.
///
/// At schedule time we also create a `pending` FatigueEntry in SwiftData so missed
/// prompts can be detected on app launch (notifications themselves don't notify us
/// when they're ignored).
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    weak var coordinator: NotificationCoordinator?
    
    static let categoryID = "FATIGUE_PROMPT"
    static let promptIDKey = "promptID"
    static let scheduledAtKey = "scheduledAt"
    
    /// Register the notification category with 5 severity buttons.
    func registerCategories() {
        // One action per zone. The action identifier carries the zone's raw value
        // (e.g. "ZONE_functioning"); the form will pre-fill the slider at the zone midpoint.
        let actions: [UNNotificationAction] = SeverityZone.allCases.map { zone in
            UNNotificationAction(
                identifier: "ZONE_\(zone.rawValue)",
                title: zone.shortLabel,
                options: [.foreground]
            )
        }
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: actions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
    
    /// Schedule notifications at regular intervals within today's active window,
    /// with jitter applied per-prompt. Also writes a `pending` FatigueEntry for
    /// each scheduled prompt so missed responses can be detected later.
    ///
    /// Removes any *future* pending notifications and their stub entries first.
    /// Past pending entries are left alone (they'll be swept to `missed` on app open).
    @MainActor
    func scheduleToday(settings: AppSettings, context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        // Delete any pending stub entries whose scheduledAt is still in the future —
        // we're about to re-schedule them with fresh jitter. Past pending entries
        // are preserved so MissedEntrySweeper can mark them missed.
        let now = Date()
        let descriptor = FetchDescriptor<FatigueEntry>(
            predicate: #Predicate { $0.statusRaw == "pending" && $0.scheduledAt > now }
        )
        if let futurePending = try? context.fetch(descriptor) {
            for entry in futurePending {
                context.delete(entry)
            }
        }
        
        let calendar = Calendar.current
        
        guard let startOfToday = calendar.date(bySettingHour: settings.activeStartHour,
                                                minute: 0, second: 0, of: now),
              let endOfToday = calendar.date(bySettingHour: settings.activeEndHour,
                                              minute: 0, second: 0, of: now)
        else { return }
        
        // Base time walks forward by the full interval each step; jitter is applied
        // per-prompt so it doesn't compound across the day.
        var baseTime = max(startOfToday, now.addingTimeInterval(60))
        let interval = TimeInterval(settings.intervalMinutes * 60)
        // 15% of the interval, in seconds, as the maximum jitter magnitude.
        let maxJitter = interval * 0.15
        
        while baseTime < endOfToday {
            let jitter = Double.random(in: -maxJitter...maxJitter)
            let fireTime = baseTime.addingTimeInterval(jitter)
            
            // Skip prompts that jitter would push outside the active window
            // or before "now" (the latter only matters for the first iteration).
            guard fireTime >= now.addingTimeInterval(30), fireTime < endOfToday else {
                baseTime = baseTime.addingTimeInterval(interval)
                continue
            }
            
            let promptID = UUID().uuidString
            
            // Persist a pending stub so we can detect missed responses later.
            let stub = FatigueEntry(promptID: promptID,
                                     scheduledAt: fireTime,
                                     status: .pending)
            context.insert(stub)
            
            let content = UNMutableNotificationContent()
            content.title = "How's your fatigue?"
            content.body = "Tap to log how you're doing"
            content.sound = .default
            content.categoryIdentifier = Self.categoryID
            content.userInfo = [
                Self.promptIDKey: promptID,
                Self.scheduledAtKey: fireTime.timeIntervalSince1970
            ]
            
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute],
                                                      from: fireTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: promptID,
                                                 content: content,
                                                 trigger: trigger)
            
            do {
                try await center.add(request)
            } catch {
                print("Failed to schedule notification: \(error)")
                // If notification scheduling fails, also remove the stub so we don't
                // end up with a phantom "missed" entry for a notification that never fired.
                context.delete(stub)
            }
            
            baseTime = baseTime.addingTimeInterval(interval)
        }
        
        try? context.save()
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Show notifications even when the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
    
    /// Handle the user tapping an action button or the notification body.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let promptID = userInfo[Self.promptIDKey] as? String,
              let scheduledTS = userInfo[Self.scheduledAtKey] as? TimeInterval
        else { return }
        
        let scheduledAt = Date(timeIntervalSince1970: scheduledTS)
        var severity: Int?
        
        if response.actionIdentifier.hasPrefix("ZONE_") {
            let rawZone = response.actionIdentifier
                .replacingOccurrences(of: "ZONE_", with: "")
            if let zone = SeverityZone(rawValue: rawZone) {
                severity = zone.notificationPrefillValue
            }
        }
        
        let pending = PendingPrompt(promptID: promptID,
                                     scheduledAt: scheduledAt,
                                     preFilledSeverity: severity)
        
        await MainActor.run {
            coordinator?.pendingPrompt = pending
        }
    }
}

/// Sweeps pending entries past their timeout and marks them as missed.
/// Called on app open.
enum MissedEntrySweeper {
    @MainActor
    static func sweep(settings: AppSettings, context: ModelContext) {
        let timeout = TimeInterval(settings.missedTimeoutMinutes * 60)
        let cutoff = Date().addingTimeInterval(-timeout)
        
        let descriptor = FetchDescriptor<FatigueEntry>(
            predicate: #Predicate { $0.statusRaw == "pending" && $0.scheduledAt < cutoff }
        )
        
        guard let stale = try? context.fetch(descriptor) else { return }
        for entry in stale {
            entry.status = .missed
        }
        try? context.save()
    }
}
