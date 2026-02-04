import SwiftUI
import FamilyControls
import DeviceActivity
import os

private let appGroupID = "group.uncle.app.v3"
private let taskTextKey = "uncleTaskText"
private let thresholdMinutesKey = "uncleThresholdMinutes"
private let uncleArmedKey = "uncleArmed"

struct TextBank {
    static func loadStrings(from filename: String) -> [String] {
        let subdirs = ["Resources/TextBanks", "TextBanks", nil] as [String?]
        for sub in subdirs {
            if let url = Bundle.main.url(forResource: filename, withExtension: "txt", subdirectory: sub),
               (try? url.checkResourceIsReachable()) == true,
               let content = try? String(contentsOf: url) {
                return content.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        }
        if let url = Bundle.main.url(forResource: filename, withExtension: "txt"),
           let content = try? String(contentsOf: url) {
            return content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        print("[Uncle] TextBank – failed to load \(filename).txt")
        return []
    }
    
    static func randomInstruction() -> String {
        let strings = loadStrings(from: "instruction_strings")
        return strings.randomElement() ?? "Hold the line."
    }
    
    static func randomMoodText(for level: Int) -> String {
        let moodFiles = ["mood_calm", "mood_concerned", "mood_irritated", "mood_disappointed"]
        let idx = min(max(0, level), moodFiles.count - 1)
        let strings = loadStrings(from: moodFiles[idx])
        if strings.isEmpty {
            print("[Uncle] TextBank – no strings loaded for \(moodFiles[idx]), level=\(level)")
            // Fallback based on level
            let fallbacks = ["Uncle is watching", "Uncle is noticing", "Uncle is firm", "Uncle is serious"]
            return fallbacks[min(idx, fallbacks.count - 1)]
        }
        return strings.randomElement() ?? "Uncle is watching"
    }
}

struct MainGoalView: View {
    @State private var showIncomingCall = false
    @State private var taskText = ""
    @State private var appsLocked = false
    @State private var instructionText = ""
    @State private var moodText = ""
    @State private var isEditingTask = false
    private let logger = Logger(subsystem: "uncle.app.v3", category: "MainGoalView")
    private let deviceActivityCenter = DeviceActivityCenter()
    private var appGroupDefaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    /// True when key is missing (default) or explicitly true. Only false when user has turned "Uncle is active" off.
    private var isUncleArmed: Bool {
        guard UserDefaults.standard.object(forKey: uncleArmedKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: uncleArmedKey)
    }

    private func refreshAppsLocked() {
        appsLocked = (UncleAppState.read(from: appGroupDefaults) == UncleAppState.lockedPendingCall)
        print("[Uncle] refreshAppsLocked – appsLocked=\(appsLocked)")
    }
    
    private func updateMoodText() {
        let (level, _) = UncleStrikeLevel.effectiveLevel(from: appGroupDefaults)
        moodText = TextBank.randomMoodText(for: level)
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Instruction string first (smaller, secondary)
            Text(instructionText.isEmpty ? "Hold the line." : instructionText)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)
            
            // Goal/task second (dominant, larger)
            if isEditingTask || taskText.isEmpty {
                VStack(alignment: .trailing, spacing: 8) {
                    TextField("Add a task", text: $taskText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2...4)
                        .onChange(of: taskText) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: taskTextKey)
                            print("[Uncle] task text saved: \(newValue.isEmpty ? "(empty)" : newValue)")
                            logger.info("task text saved")
                        }
                    Button {
                        isEditingTask = false
                    } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    isEditingTask = true
                } label: {
                    Text(taskText)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 80)
        .padding(.horizontal, 36)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 1.0, green: 0.90, blue: 0.80))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    var body: some View {
        GeometryReader { geo in
            NavigationStack {
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        Spacer()
                        
                        instructionCard
                            .padding(.horizontal, 24)
                        
                        if appsLocked {
                            Button("Call Uncle") {
                                print("[Uncle] Call Uncle tapped")
                                logger.info("Call Uncle tapped")
                                showIncomingCall = true
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Spacer()
                        
                        Text(moodText.isEmpty ? "Uncle is watching" : moodText)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, max(24, geo.safeAreaInsets.bottom + 16))
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            print("[Uncle] MainGoalView – gear tapped, navigating to Settings")
                            logger.info("MainGoalView – gear tapped → navigating to Settings")
                        })
                    }
                }
                .navigationDestination(isPresented: $showIncomingCall) {
                    IncomingCallView(isCallPresented: { showIncomingCall })
                }
                .onReceive(NotificationCenter.default.publisher(for: .uncleShowIncomingCall)) { _ in
                    print("[Uncle] MainGoalView – received ShowIncomingCall notification, opening Incoming Call screen")
                    logger.info("MainGoalView – opened from notification → showing Incoming Call")
                    showIncomingCall = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .uncleRestartMonitoring)) { _ in
                    restartMonitoring()
                    refreshAppsLocked()
                    updateMoodText()
                }
                .onChange(of: showIncomingCall) { _, isShowing in
                    if !isShowing {
                        refreshAppsLocked()
                        updateMoodText()
                    }
                }
            }
        }
        .onAppear {
            taskText = UserDefaults.standard.string(forKey: taskTextKey) ?? ""
            instructionText = TextBank.randomInstruction()
            refreshAppsLocked()
            updateMoodText()
            print("[Uncle] main/goal screen appeared")
            logger.info("main/goal screen appeared")
            if isUncleArmed,
               let data = appGroupDefaults?.data(forKey: "familyActivitySelection"),
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
        guard isUncleArmed else {
            print("[Uncle] restartMonitoring – Uncle disarmed, skipping")
            logger.info("restartMonitoring – disarmed, skipping")
            return
        }
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
