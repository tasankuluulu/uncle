import SwiftUI
import FamilyControls
import DeviceActivity
import os

private let appGroupID = "group.uncle.app.v3"
private let taskTextKey = "uncleTaskText"
private let thresholdMinutesKey = "uncleThresholdMinutes"

struct DebugView: View {
    @State private var showIncomingCall = false
    @State private var taskText = ""
    @State private var appsLocked = false
    private let logger = Logger(subsystem: "uncle.app.v3", category: "DebugView")
    private let deviceActivityCenter = DeviceActivityCenter()
    private var appGroupDefaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    private func refreshAppsLocked() {
        appsLocked = (UncleAppState.read(from: appGroupDefaults) == UncleAppState.lockedPendingCall)
        print("[Uncle] refreshAppsLocked – appsLocked=\(appsLocked)")
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus on what matters.")
                .font(.headline)
            TextField("Add a task", text: $taskText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .onChange(of: taskText) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: taskTextKey)
                    print("[Uncle] task text saved: \(newValue.isEmpty ? "(empty)" : newValue)")
                    logger.info("task text saved")
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.bottom, 8)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    instructionCard
                    if appsLocked {
                        Button("Call Uncle") {
                            print("[Uncle] Call Uncle tapped")
                            logger.info("Call Uncle tapped")
                            showIncomingCall = true
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        print("[Uncle] DebugView – gear tapped, navigating to Settings")
                        logger.info("DebugView – gear tapped → navigating to Settings")
                    })
                }
            }
            .navigationDestination(isPresented: $showIncomingCall) {
                IncomingCallView(isCallPresented: { showIncomingCall })
            }
            .onReceive(NotificationCenter.default.publisher(for: .uncleShowIncomingCall)) { _ in
                print("[Uncle] DebugView – received ShowIncomingCall notification, opening Incoming Call screen")
                logger.info("DebugView – opened from notification → showing Incoming Call")
                showIncomingCall = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .uncleRestartMonitoring)) { _ in
                restartMonitoring()
                refreshAppsLocked()
            }
            .onChange(of: showIncomingCall) { _, isShowing in
                if !isShowing { refreshAppsLocked() }
            }
        }
        .onAppear {
            taskText = UserDefaults.standard.string(forKey: taskTextKey) ?? ""
            refreshAppsLocked()
            print("[Uncle] main/goal screen appeared")
            logger.info("main/goal screen appeared")
            if let data = appGroupDefaults?.data(forKey: "familyActivitySelection"),
               let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data),
               (!decoded.applicationTokens.isEmpty || !decoded.categoryTokens.isEmpty || !decoded.webDomainTokens.isEmpty),
               UserDefaults.standard.bool(forKey: "uncleOnboardingComplete") {
                startMonitoring(with: decoded)
                print("[Uncle] auto-started monitoring: \(decoded.applicationTokens.count) app(s)")
                logger.info("auto-started monitoring: \(decoded.applicationTokens.count, privacy: .public) app(s)")
            }
            if UserDefaults.standard.bool(forKey: "UncleOpenIncomingCallFromNotification") {
                print("[Uncle] onAppear: opened from notification → Incoming Call")
                logger.info("onAppear: opened from notification → Incoming Call")
                UserDefaults.standard.set(false, forKey: "UncleOpenIncomingCallFromNotification")
                showIncomingCall = true
            }
        }
    }

    private func restartMonitoring() {
        guard let data = appGroupDefaults?.data(forKey: "familyActivitySelection"),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data),
              !decoded.applicationTokens.isEmpty || !decoded.categoryTokens.isEmpty || !decoded.webDomainTokens.isEmpty else {
            print("[Uncle] restartMonitoring – no valid selection, skipping")
            return
        }
        print("[Uncle] restartMonitoring – stopping then starting monitoring")
        logger.info("restartMonitoring – stop then start")
        deviceActivityCenter.stopMonitoring([.oneMinuteMonitoring])
        startMonitoring(with: decoded)
    }

    private func startMonitoring(with selection: FamilyActivitySelection) {
        let sel = selection
        print("[Uncle] startMonitoring called")
        logger.info("startMonitoring called")
        let hasSelection = !sel.applicationTokens.isEmpty || !sel.categoryTokens.isEmpty || !sel.webDomainTokens.isEmpty
        guard hasSelection else {
            print("[Uncle] startMonitoring ABORT: no target app selected. Pick an app first.")
            logger.error("startMonitoring ABORT: no apps selected – Pick Target Apps first")
            return
        }
        let count = sel.applicationTokens.count + sel.categoryTokens.count + sel.webDomainTokens.count
        print("[Uncle] startMonitoring – monitoring \(count) app(s)")
        logger.info("startMonitoring – monitoring \(count, privacy: .public) app(s)")
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        print("[Uncle] startMonitoring – schedule: 00:00–23:59, repeats=true")
        logger.info("startMonitoring – schedule 00:00–23:59 repeats=true")
        let thresholdMin = max(1, min(60, Int(UserDefaults.standard.string(forKey: thresholdMinutesKey) ?? "1") ?? 1))
        let event = DeviceActivityEvent(
            applications: sel.applicationTokens,
            categories: sel.categoryTokens,
            webDomains: sel.webDomainTokens,
            threshold: DateComponents(minute: thresholdMin)
        )
        print("[Uncle] startMonitoring – event: threshold=\(thresholdMin) min, activityName=oneMinuteMonitoring, eventName=oneMinuteThreshold")
        logger.info("startMonitoring – event threshold=\(thresholdMin, privacy: .public) min")
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [.oneMinuteThreshold: event]
        do {
            try deviceActivityCenter.startMonitoring(.oneMinuteMonitoring, during: schedule, events: events)
            print("[Uncle] startMonitoring SUCCESS – DeviceActivityCenter.startMonitoring() returned. Activity=oneMinuteMonitoring.")
            logger.info("startMonitoring SUCCESS – monitoring \(count, privacy: .public) app(s)")
            let now = Date()
            print("[Uncle] startMonitoring – current time: \(now)")
            print("[Uncle] NOTE: Extension runs on device only. Use the SELECTED app for 1+ min. If threshold fires but no shield: Console may show 'Could not find any extensions matching NSExtensionContainingApp'. Try: delete app, Product > Clean Build Folder, reinstall; or restart device (known iOS bug FB13556935).")
            logger.info("startMonitoring – time: \(now, privacy: .public)")
        } catch {
            print("[Uncle] startMonitoring FAILED: \(error)")
            logger.error("startMonitoring FAILED: \(String(describing: error), privacy: .public)")
        }
    }
}
