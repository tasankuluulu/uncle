import SwiftUI
import UserNotifications
import os

@main
struct UncleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let logger = Logger(subsystem: "com.uncle.app", category: "AppDelegate")

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("[Uncle] application didFinishLaunchingWithOptions")
        logger.info("application didFinishLaunchingWithOptions")
        UNUserNotificationCenter.current().delegate = self
        checkFallbackShieldNotification()
        routeFromPersistedState()
        return true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("[Uncle] applicationWillEnterForeground")
        logger.info("applicationWillEnterForeground")
        checkFallbackShieldNotification()
        routeFromPersistedState()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("[Uncle] NOTIFICATION willPresent: \(notification.request.identifier)")
        logger.info("NOTIFICATION willPresent: \(notification.request.identifier, privacy: .public)")
        // Use both .banner (tappable, shows at top) and .list (persistent in Notification Center)
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        print("[Uncle] NOTIFICATION didReceive (tap): \(identifier), action=\(response.actionIdentifier)")
        logger.info("NOTIFICATION didReceive tap: \(identifier, privacy: .public) action=\(response.actionIdentifier, privacy: .public)")
        if identifier == "uncle-shield-trigger" {
            print("[Uncle] NOTIFICATION tap handling path: opened from shield notification → posting ShowIncomingCall → Incoming Call screen will be shown")
            logger.info("NOTIFICATION tap – routing to Incoming Call screen")
            UserDefaults.standard.set(true, forKey: "UncleOpenIncomingCallFromNotification")
            NotificationCenter.default.post(name: .uncleShowIncomingCall, object: nil)
        }
        completionHandler()
    }

    private func routeFromPersistedState() {
        let defaults = UserDefaults(suiteName: UncleAppState.appGroupID)
        let state = UncleAppState.read(from: defaults)
        print("[Uncle] app: routing – state=\(state) → Main (Incoming Call only via notification tap or Call Uncle)")
        logger.info("app: routing – state=\(state, privacy: .public) → Main")
    }

    private func checkFallbackShieldNotification() {
        guard let defaults = UserDefaults(suiteName: "group.uncle.app.v3"),
              defaults.bool(forKey: "uncleScheduleShieldNotification") else { return }
        print("[Uncle] checkFallbackShieldNotification – fallback flag set, scheduling notification from app")
        logger.info("checkFallbackShieldNotification – fallback approach")
        defaults.set(false, forKey: "uncleScheduleShieldNotification")
        defaults.synchronize()
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
        let request = UNNotificationRequest(identifier: "uncle-shield-trigger", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("[Uncle] checkFallbackShieldNotification – schedule FAILED: \(error)")
                self?.logger.error("fallback schedule FAILED: \(String(describing: error), privacy: .public)")
            } else {
                print("[Uncle] checkFallbackShieldNotification – fallback: scheduled notification identifier: uncle-shield-trigger")
                self?.logger.info("fallback: scheduled notification SUCCESS")
            }
        }
    }
}

extension Notification.Name {
    static let uncleShowIncomingCall = Notification.Name("UncleShowIncomingCall")
    static let uncleOnboardingComplete = Notification.Name("UncleOnboardingComplete")
    static let uncleRestartMonitoring = Notification.Name("UncleRestartMonitoring")
}

private let onboardingCompleteKey = "uncleOnboardingComplete"

struct RootView: View {
    @State private var onboardingComplete = UserDefaults.standard.bool(forKey: onboardingCompleteKey)

    var body: some View {
        Group {
            if onboardingComplete {
                MainGoalView()
            } else {
                OnboardingView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .uncleOnboardingComplete)) { _ in
            onboardingComplete = true
            print("[Uncle] RootView – onboarding complete, switching to main")
        }
    }
}
