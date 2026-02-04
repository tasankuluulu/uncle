import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications
import os

private let appGroupID = "group.uncle.app.v3"
private let shieldNotificationID = "uncle-shield-trigger"
private let fallbackFlagKey = "uncleScheduleShieldNotification"

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(subsystem: "uncle.app.v3.devicemonitor", category: "DeviceActivityMonitor")

    override init() {
        super.init()
        print("[Uncle DeviceMonitor] init – extension loaded")
        logger.info("init – extension loaded")
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        print("[Uncle DeviceMonitor] intervalDidStart: \(activity.rawValue) – schedule is active; threshold will fire after 1 min of selected app usage")
        logger.info("intervalDidStart: \(activity.rawValue, privacy: .public)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        print("[Uncle DeviceMonitor] intervalDidEnd: \(activity.rawValue) – schedule interval ended")
        logger.info("intervalDidEnd: \(activity.rawValue, privacy: .public)")
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        print("[Uncle DeviceMonitor] eventDidReachThreshold CALLBACK FIRED – event=\(event.rawValue) activity=\(activity.rawValue) – applying shield now")
        logger.info("eventDidReachThreshold CALLBACK: event=\(event.rawValue, privacy: .public) activity=\(activity.rawValue, privacy: .public)")
        incrementStrikeLevel()
        applyShieldForThreshold()
        setStateLockedPendingCall()
        scheduleShieldNotification()
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        print("[Uncle DeviceMonitor] intervalWillStartWarning: \(activity.rawValue)")
        logger.info("intervalWillStartWarning: \(activity.rawValue, privacy: .public)")
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        print("[Uncle DeviceMonitor] intervalWillEndWarning: \(activity.rawValue)")
        logger.info("intervalWillEndWarning: \(activity.rawValue, privacy: .public)")
    }

    private func applyShieldForThreshold() {
        print("[Uncle DeviceMonitor] applyShieldForThreshold – step 1: open App Group suiteName=\(appGroupID)")
        logger.info("applyShieldForThreshold – opening App Group")
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("[Uncle DeviceMonitor] applyShieldForThreshold FAILED – UserDefaults(suiteName: \(appGroupID)) returned nil")
            logger.error("applyShieldForThreshold FAILED: UserDefaults suite nil")
            return
        }
        print("[Uncle DeviceMonitor] applyShieldForThreshold – step 2: read data for key familyActivitySelection")
        guard let data = defaults.data(forKey: "familyActivitySelection") else {
            print("[Uncle DeviceMonitor] applyShieldForThreshold FAILED – no data for key familyActivitySelection (main app may not have saved selection)")
            logger.error("applyShieldForThreshold FAILED: no data in App Group")
            return
        }
        print("[Uncle DeviceMonitor] applyShieldForThreshold – step 3: decode FamilyActivitySelection, data count=\(data.count) bytes")
        do {
            let selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            let appCount = selection.applicationTokens.count
            let catCount = selection.categoryTokens.count
            let webCount = selection.webDomainTokens.count
            print("[Uncle DeviceMonitor] applyShieldForThreshold – step 4: decode OK, apps=\(appCount) categories=\(catCount) webDomains=\(webCount)")
            logger.info("applyShieldForThreshold – decoded apps=\(appCount, privacy: .public) categories=\(catCount, privacy: .public)")
            let hasSelection = !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
            guard hasSelection else {
                print("[Uncle DeviceMonitor] applyShieldForThreshold – no tokens, skipping shield")
                logger.info("applyShieldForThreshold – no tokens, skipping")
                return
            }
            print("[Uncle DeviceMonitor] applyShieldForThreshold – step 5: set ManagedSettingsStore().shield")
            let store = ManagedSettingsStore()
            store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
            print("[Uncle DeviceMonitor] applyShieldForThreshold – step 6: SHIELD APPLIED")
            logger.info("applyShieldForThreshold – SHIELD APPLIED")
        } catch {
            print("[Uncle DeviceMonitor] applyShieldForThreshold FAILED to decode: \(error)")
            logger.error("applyShieldForThreshold decode FAILED: \(String(describing: error), privacy: .public)")
        }
    }

    private func scheduleShieldNotification() {
        print("[Uncle DeviceMonitor] scheduleShieldNotification – attempting direct scheduling")
        logger.info("scheduleShieldNotification – direct approach")
        let content = UNMutableNotificationContent()
        content.title = "Uncle is calling."
        content.body = "You crossed the line. Answer it."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("uncle_ringing.caf"))
        content.badge = 1
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
        content.categoryIdentifier = "uncle_call"
        let request = UNNotificationRequest(identifier: shieldNotificationID, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("[Uncle DeviceMonitor] scheduleShieldNotification FAILED (direct): \(error) – using fallback")
                self?.logger.error("scheduleShieldNotification FAILED: \(String(describing: error), privacy: .public) – fallback")
                self?.writeFallbackFlag()
            } else {
                print("[Uncle DeviceMonitor] scheduleShieldNotification SUCCESS – scheduled identifier: \(shieldNotificationID)")
                self?.logger.info("scheduleShieldNotification SUCCESS – identifier: \(shieldNotificationID, privacy: .public)")
            }
        }
    }

    private func incrementStrikeLevel() {
        guard let defaults = UserDefaults(suiteName: UncleAppState.appGroupID) else { return }
        let (level, reason) = UncleStrikeLevel.effectiveLevel(from: defaults)
        let newLevel = min(UncleAppState.strikeCap, level + 1)
        let now = Date()
        UncleAppState.writeStrikeLevel(newLevel, to: defaults)
        UncleAppState.writeLastLockAt(now, to: defaults)
        print("[Uncle DeviceMonitor] strike level changed: \(level) → \(newLevel) (lock trigger) reason=\(reason)")
        logger.info("strike level changed: \(level, privacy: .public) → \(newLevel, privacy: .public) (lock trigger) reason=\(reason, privacy: .public)")
    }

    private func setStateLockedPendingCall() {
        guard let defaults = UserDefaults(suiteName: UncleAppState.appGroupID) else {
            print("[Uncle DeviceMonitor] setStateLockedPendingCall FAILED – UserDefaults suite nil")
            return
        }
        let oldState = UncleAppState.read(from: defaults)
        UncleAppState.write(UncleAppState.lockedPendingCall, to: defaults)
        print("[Uncle DeviceMonitor] STATE extension: \(oldState) → \(UncleAppState.lockedPendingCall)")
        logger.info("STATE extension: \(oldState, privacy: .public) → \(UncleAppState.lockedPendingCall, privacy: .public)")
    }

    private func writeFallbackFlag() {
        print("[Uncle DeviceMonitor] writeFallbackFlag – writing to App Group")
        logger.info("writeFallbackFlag – App Group fallback")
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("[Uncle DeviceMonitor] writeFallbackFlag FAILED – UserDefaults suite nil")
            return
        }
        defaults.set(true, forKey: fallbackFlagKey)
        defaults.synchronize()
        print("[Uncle DeviceMonitor] writeFallbackFlag – flag set, app will schedule on foreground")
    }
}
