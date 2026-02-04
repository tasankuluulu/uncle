import SwiftUI
import FamilyControls
import ManagedSettingsUI
import UserNotifications
import DeviceActivity
import ManagedSettings
import os

private let appGroupID = "group.uncle.app.v3"
private let allowSwearingKey = "uncleAllowSwearing"
private let thresholdMinutesKey = "uncleThresholdMinutes"
private let userNameKey = "uncleUserName"
private let taskTextKey = "uncleTaskText"
private let uncleArmedKey = "uncleArmed"

private let accentTeal = Color(red: 0.11, green: 0.27, blue: 0.35)

struct SettingsView: View {
    @AppStorage(allowSwearingKey) private var allowSwearing = false
    @AppStorage(thresholdMinutesKey) private var thresholdMinutesStr = "1"
    @AppStorage(userNameKey) private var userName = ""
    @AppStorage(taskTextKey) private var taskText = ""
    @State private var selectedApps = FamilyActivitySelection()
    @State private var showFamilyPicker = false
    @State private var notificationAuthorized = false
    @State private var isEditingName = false
    @State private var isEditingTask = false
    @AppStorage(uncleArmedKey) private var uncleArmed = true
    private let logger = Logger(subsystem: "uncle.app.v3", category: "SettingsView")
    private let authorizationCenter = AuthorizationCenter.shared
    private let deviceActivityCenter = DeviceActivityCenter()
    private var appGroupDefaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    private var selectionCountText: String {
        let apps = selectedApps.applicationTokens.count
        let categories = selectedApps.categoryTokens.count
        let sites = selectedApps.webDomainTokens.count
        guard apps > 0 || categories > 0 || sites > 0 else { return "None" }
        var parts: [String] = []
        if apps > 0 { parts.append(apps == 1 ? "1 app" : "\(apps) apps") }
        if categories > 0 { parts.append(categories == 1 ? "1 category" : "\(categories) categories") }
        if sites > 0 { parts.append(sites == 1 ? "1 site" : "\(sites) sites") }
        return parts.joined(separator: ", ")
    }

    private var thresholdMinutes: Binding<Int> {
        Binding(
            get: { Int(thresholdMinutesStr) ?? 1 },
            set: { thresholdMinutesStr = String($0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Section
                settingsCard(title: "Profile") {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Name")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        if isEditingName {
                            HStack {
                                TextField("Your name", text: $userName)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 17, weight: .regular))
                                Button("Done") {
                                    isEditingName = false
                                }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(accentTeal)
                            }
                        } else {
                            Button {
                                isEditingName = true
                            } label: {
                                HStack {
                                    Text(userName.isEmpty ? "Tap to add name" : userName)
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundStyle(userName.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Monitoring Section
                settingsCard(title: "Monitoring") {
                    VStack(spacing: 16) {
                        Button {
                            showFamilyPicker = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Target apps")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundStyle(.primary)
                                    Text(selectionCountText)
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Call Settings Section
                settingsCard(title: "Call") {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Task")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                            if isEditingTask {
                                VStack(alignment: .trailing, spacing: 8) {
                                    TextField("What are you supposed to be doing?", text: $taskText, axis: .vertical)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 17, weight: .regular))
                                        .lineLimit(2...4)
                                    Button("Done") {
                                        isEditingTask = false
                                    }
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(accentTeal)
                                }
                            } else {
                                Button {
                                    isEditingTask = true
                                } label: {
                                    HStack {
                                        Text(taskText.isEmpty ? "Tap to set task" : taskText)
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundStyle(taskText.isEmpty ? .secondary : .primary)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Image(systemName: "pencil")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Threshold")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                TextField("Minutes", text: $thresholdMinutesStr)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 17, weight: .regular))
                                    .keyboardType(.numberPad)
                                    .frame(maxWidth: 80)
                                    .onChange(of: thresholdMinutesStr) { oldValue, newValue in
                                        // Only allow numeric input
                                        let filtered = newValue.filter { $0.isNumber }
                                        
                                        if filtered.isEmpty {
                                            thresholdMinutesStr = "1"
                                            return
                                        }
                                        
                                        if let num = Int(filtered) {
                                            // Clamp to valid range
                                            let clamped = min(max(num, 1), 60)
                                            if clamped != num {
                                                thresholdMinutesStr = String(clamped)
                                            } else if filtered != newValue {
                                                thresholdMinutesStr = filtered
                                            }
                                        } else {
                                            // Fallback: restore old value
                                            thresholdMinutesStr = oldValue
                                        }
                                    }
                                Text("min")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // General Section
                settingsCard(title: "General") {
                    VStack(spacing: 16) {
                        Toggle(isOn: $allowSwearing) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Allow swearing")
                                    .font(.system(size: 17, weight: .regular))
                                Text("Uncle can use stronger language")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(accentTeal)
                        
                        Divider()
                        
                        Toggle(isOn: $uncleArmed) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Uncle is active")
                                    .font(.system(size: 17, weight: .regular))
                                Text(uncleArmed ? "Monitoring and ready to call" : "Monitoring stopped")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(accentTeal)
                        .onChange(of: uncleArmed) { _, newValue in
                            if newValue {
                                armUncle()
                            } else {
                                disarmUncle()
                            }
                        }
                    }
                }

                // Permissions Section
                settingsCard(title: "Permissions") {
                    VStack(spacing: 16) {
                        permissionRow(
                            title: "Screen Time",
                            status: authorizationCenter.authorizationStatus == .approved ? "Authorized" : "Not authorized",
                            isAuthorized: authorizationCenter.authorizationStatus == .approved
                        )
                        Divider()
                        permissionRow(
                            title: "Notifications",
                            status: notificationAuthorized ? "Authorized" : "Not authorized",
                            isAuthorized: notificationAuthorized
                        )
                    }
                } footer: {
                    Text("Manage permissions in iOS Settings")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showFamilyPicker) {
            VStack(spacing: 0) {
                FamilyActivityPicker(selection: $selectedApps)
                Button("Save") {
                    saveSelectionAndClosePicker()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .buttonStyle(.borderedProminent)
                .tint(accentTeal)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Initialize uncleArmed to true if not set (first launch)
            if UserDefaults.standard.object(forKey: uncleArmedKey) == nil {
                uncleArmed = true
            }
            checkNotificationStatus()
            loadSelectedApps()
            print("[Uncle] SettingsView – screen appeared")
            logger.info("SettingsView – navigated to Settings")
        }
        .onDisappear {
            print("[Uncle] SettingsView – screen disappeared")
            logger.info("SettingsView – navigated back from Settings")
        }
    }

    private func settingsCard<Content: View, Footer: View>(title: String, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
            footer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        settingsCard(title: title, content: content) {
            EmptyView()
        }
    }

    private func permissionRow(title: String, status: String, isAuthorized: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                Text(status)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(isAuthorized ? accentTeal : .secondary)
            }
            Spacer()
            Image(systemName: isAuthorized ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isAuthorized ? accentTeal : .orange)
        }
    }

    private func loadSelectedApps() {
        guard let data = appGroupDefaults?.data(forKey: "familyActivitySelection"),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
        selectedApps = decoded
    }

    private func saveSelectionAndClosePicker() {
        do {
            let data = try JSONEncoder().encode(selectedApps)
            appGroupDefaults?.set(data, forKey: "familyActivitySelection")
            appGroupDefaults?.synchronize()
            print("[Uncle] Settings – saved target apps")
            logger.info("Settings – saved target apps")
            
            // Restart monitoring if armed and selection is valid
            if uncleArmed, !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty || !selectedApps.webDomainTokens.isEmpty {
                deviceActivityCenter.stopMonitoring([.oneMinuteMonitoring])
                startMonitoring(with: selectedApps)
            }
        } catch {
            print("[Uncle] Settings – failed to save selection: \(error)")
        }
        showFamilyPicker = false
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }

    private func disarmUncle() {
        print("[Uncle] Settings – disarming Uncle")
        logger.info("Settings – disarming Uncle")
        
        // Stop monitoring
        deviceActivityCenter.stopMonitoring([.oneMinuteMonitoring])
        
        // Clear shields
        let store = ManagedSettingsStore()
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        
        // Set state to idle
        UncleAppState.write(UncleAppState.idle, to: appGroupDefaults)
        
        print("[Uncle] Settings – Uncle disarmed: monitoring stopped, shields cleared")
        logger.info("Settings – Uncle disarmed")
    }

    private func armUncle() {
        print("[Uncle] Settings – arming Uncle")
        logger.info("Settings – arming Uncle")
        
        // Load selection and restart monitoring if available
        guard let data = appGroupDefaults?.data(forKey: "familyActivitySelection"),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data),
              !decoded.applicationTokens.isEmpty || !decoded.categoryTokens.isEmpty || !decoded.webDomainTokens.isEmpty else {
            print("[Uncle] Settings – no selection available, cannot arm")
            logger.info("Settings – no selection, cannot arm")
            return
        }
        
        startMonitoring(with: decoded)
        print("[Uncle] Settings – Uncle armed: monitoring started")
        logger.info("Settings – Uncle armed")
    }

    private func startMonitoring(with selection: FamilyActivitySelection) {
        let sel = selection
        let hasSelection = !sel.applicationTokens.isEmpty || !sel.categoryTokens.isEmpty || !sel.webDomainTokens.isEmpty
        guard hasSelection else {
            print("[Uncle] Settings – startMonitoring ABORT: no target app selected")
            logger.error("Settings – startMonitoring ABORT: no apps selected")
            return
        }
        let count = sel.applicationTokens.count + sel.categoryTokens.count + sel.webDomainTokens.count
        print("[Uncle] Settings – startMonitoring – monitoring \(count) app(s)")
        logger.info("Settings – startMonitoring – monitoring \(count, privacy: .public) app(s)")
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let thresholdMin = max(1, min(60, Int(thresholdMinutesStr) ?? 1))
        let event = DeviceActivityEvent(
            applications: sel.applicationTokens,
            categories: sel.categoryTokens,
            webDomains: sel.webDomainTokens,
            threshold: DateComponents(minute: thresholdMin)
        )
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [.oneMinuteThreshold: event]
        do {
            try deviceActivityCenter.startMonitoring(.oneMinuteMonitoring, during: schedule, events: events)
            print("[Uncle] Settings – startMonitoring SUCCESS")
            logger.info("Settings – startMonitoring SUCCESS")
        } catch {
            print("[Uncle] Settings – startMonitoring FAILED: \(error)")
            logger.error("Settings – startMonitoring FAILED: \(String(describing: error), privacy: .public)")
        }
    }
}
