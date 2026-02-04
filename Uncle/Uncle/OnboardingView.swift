import SwiftUI
import FamilyControls
import ManagedSettingsUI
import DeviceActivity
import UserNotifications
import os

private let appGroupID = "group.uncle.app.v3"
private let onboardingCompleteKey = "uncleOnboardingComplete"
private let userNameKey = "uncleUserName"
private let allowSwearingKey = "uncleAllowSwearing"
private let thresholdMinutesKey = "uncleThresholdMinutes"
private let taskTextKey = "uncleTaskText"
private let demoNotificationID = "uncle-shield-trigger"

struct OnboardingView: View {
    @State private var step = 0
    @State private var showIncomingCall = false
    @State private var selectedApps = FamilyActivitySelection()
    @State private var showFamilyPicker = false
    @State private var thresholdMinutes = 1
    @State private var userName = ""
    @State private var allowSwearing = false
    @State private var goalText = ""
    @State private var goalPresetIndex: Int? = nil
    @State private var notificationAuthorized = false
    @State private var screenTimeApproved = false
    @State private var welcomeLinesRevealed = false
    @State private var testCallSent = false
    private let logger = Logger(subsystem: "uncle.app.v3", category: "OnboardingView")
    private let authorizationCenter = AuthorizationCenter.shared
    private var appGroupDefaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 0: contextStep
                case 1: nameStep
                case 2: authStep
                case 3: notificationsStep
                case 4: pickAppStep
                case 5: thresholdStep
                case 6: swearingStep
                case 7: goalStep
                case 8: demoStep
                case 9: finishStep
                default: contextStep
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: step) { _, newStep in
                if newStep != 0 { welcomeLinesRevealed = false }
            }
            .toolbar {
                if step > 0 && step < 9 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") {
                            step -= 1
                            print("[Uncle] Onboarding – back to step \(step)")
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showIncomingCall) {
                IncomingCallView(isCallPresented: { showIncomingCall }, isDemo: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .uncleShowIncomingCall)) { _ in
                print("[Uncle] Onboarding – received ShowIncomingCall, opening Incoming Call")
                logger.info("Onboarding – ShowIncomingCall → Incoming Call")
                showIncomingCall = true
            }
            .sheet(isPresented: $showFamilyPicker) {
                VStack(spacing: 0) {
                    FamilyActivityPicker(selection: $selectedApps)
                    Button("Save") {
                        saveSelectionAndClosePicker()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            print("[Uncle] OnboardingView appeared – step \(step)")
            logger.info("OnboardingView appeared – step \(step, privacy: .public)")
            thresholdMinutes = Int(UserDefaults.standard.string(forKey: thresholdMinutesKey) ?? "1") ?? 1
            userName = UserDefaults.standard.string(forKey: userNameKey) ?? ""
            goalText = UserDefaults.standard.string(forKey: taskTextKey) ?? ""
            allowSwearing = UserDefaults.standard.bool(forKey: allowSwearingKey)
            if let data = appGroupDefaults?.data(forKey: "familyActivitySelection"),
               let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data),
               (!decoded.applicationTokens.isEmpty || !decoded.categoryTokens.isEmpty || !decoded.webDomainTokens.isEmpty) {
                selectedApps = decoded
            }
        }
    }

    private static let onboardingTotalSteps = 10
    private static let accentTeal = Color(red: 0.11, green: 0.27, blue: 0.35)

    private func welcomeBodyLine(_ text: String, index: Int) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .opacity(welcomeLinesRevealed ? 1 : 0)
            .offset(x: 0, y: welcomeLinesRevealed ? 0 : 24)
            .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.12), value: welcomeLinesRevealed)
            .padding(.vertical, 3)
    }

    private func onboardingProgressBars(currentStep: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.onboardingTotalSteps, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(index <= currentStep ? Self.accentTeal : Color.gray.opacity(0.25))
                    .frame(height: 5)
                    .animation(.easeInOut(duration: 0.25), value: currentStep)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    private var contextStep: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Hero area with gradient and icon — centered
                VStack(alignment: .center, spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.11, green: 0.27, blue: 0.35),
                                        Color(red: 0.08, green: 0.18, blue: 0.24)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
                        Image(systemName: "phone.badge.waveform.fill")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.95, green: 0.80, blue: 0.45), Color(red: 0.85, green: 0.62, blue: 0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .padding(.top, max(24, geo.safeAreaInsets.top + 16))

                    VStack(alignment: .center, spacing: 0) {
                        Text("Welcome to Uncle")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                            .padding(.bottom, 20)
                        welcomeBodyLine("Some tough love when it's time to stop.", index: 0)
                        //Spacer().frame(height: 10)
                        welcomeBodyLine("Use an app too long — it locks.", index: 1)
                        welcomeBodyLine("Uncle calls.", index: 2)
                        welcomeBodyLine("You answer, listen, and access is restored.", index: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            welcomeLinesRevealed = true
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 32)

                // Progress bars and CTA
                VStack(spacing: 20) {
                    onboardingProgressBars(currentStep: 0)

                    Button {
                        step = 1
                        print("[Uncle] Onboarding – context done, step=1 (name)")
                        logger.info("Onboarding – step 0 → 1")
                    } label: {
                        Text("Begin")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.11, green: 0.27, blue: 0.35))
                    .padding(.horizontal, 4)
                }
                .padding(.bottom, max(24, geo.safeAreaInsets.bottom + 16))
            }
        }
    }

    private var nameStep: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(alignment: .center, spacing: 28) {
                    Text("What should Uncle call you?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.top, max(24, geo.safeAreaInsets.top + 16))

                    // Underline-style name field
                    VStack(spacing: 8) {
                        TextField("Your name", text: $userName)
                            .font(.system(size: 20, weight: .medium))
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.plain)
                            .textContentType(.name)
                            .frame(maxWidth: 280)
                            .padding(.vertical, 12)
                        Rectangle()
                            .fill(Self.accentTeal.opacity(0.5))
                            .frame(height: 2)
                            .frame(maxWidth: 280)
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 32)

                VStack(spacing: 20) {
                    onboardingProgressBars(currentStep: 1)
                    Button {
                        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
                        UserDefaults.standard.set(name.isEmpty ? nil : name, forKey: userNameKey)
                        step = 2
                        print("[Uncle] Onboarding – name done, step=2 (auth)")
                        logger.info("Onboarding – step 1 → 2")
                    } label: {
                        Text("That's me")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Self.accentTeal)
                    .padding(.horizontal, 4)
                }
                .padding(.bottom, max(24, geo.safeAreaInsets.bottom + 16))
            }
        }
    }

    private var authStep: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(alignment: .center, spacing: 20) {
                    Text("Let Uncle step in")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.top, max(24, geo.safeAreaInsets.top + 16))

                    VStack(alignment: .center, spacing: 12) {
                        Text("Uncle needs Screen Time access to lock apps when you cross the limit.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text("Without this, Uncle can't do anything.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 32)

                VStack(spacing: 20) {
                    onboardingProgressBars(currentStep: 2)
                    Button {
                        if screenTimeApproved {
                            step = 3
                            print("[Uncle] Onboarding – auth done, step=3 (notifications)")
                            logger.info("Onboarding – step 2 → 3")
                        } else {
                            requestScreenTimeAuthorization()
                        }
                    } label: {
                        Text(screenTimeApproved ? "Continue" : "Allow access")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Self.accentTeal)
                    .padding(.horizontal, 4)
                }
                .padding(.bottom, max(24, geo.safeAreaInsets.bottom + 16))
            }
        }
        .onAppear {
            screenTimeApproved = (authorizationCenter.authorizationStatus == .approved)
        }
    }

    private var notificationsStep: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(alignment: .center, spacing: 20) {
                    Text("Don't miss the call")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.top, max(24, geo.safeAreaInsets.top + 16))

                    Text("Uncle uses notifications to call you when it's time to stop.")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    Text(notificationAuthorized ? "✓ Notifications enabled" : "Notifications required")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(notificationAuthorized ? Self.accentTeal : .secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 32)

                VStack(spacing: 20) {
                    onboardingProgressBars(currentStep: 3)
                    Button {
                        if notificationAuthorized {
                            step = 4
                            print("[Uncle] Onboarding – notifications done, step=4 (pick app)")
                            logger.info("Onboarding – step 3 → 4")
                        } else {
                            requestNotificationPermission()
                        }
                    } label: {
                        Text(notificationAuthorized ? "Continue" : "Allow notifications")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Self.accentTeal)
                    .padding(.horizontal, 4)
                }
                .padding(.bottom, max(24, geo.safeAreaInsets.bottom + 16))
            }
        }
        .onAppear {
            checkNotificationStatus()
        }
    }

    private func selectionConfirmationText(selection: FamilyActivitySelection) -> String? {
        let apps = selection.applicationTokens.count
        let categories = selection.categoryTokens.count
        let sites = selection.webDomainTokens.count
        guard apps > 0 || categories > 0 || sites > 0 else { return nil }
        var parts: [String] = []
        if apps > 0 { parts.append(apps == 1 ? "1 app" : "\(apps) apps") }
        if categories > 0 { parts.append(categories == 1 ? "1 category" : "\(categories) categories") }
        if sites > 0 { parts.append(sites == 1 ? "1 site" : "\(sites) sites") }
        return "✓ " + parts.joined(separator: ", ") + " selected"
    }

    private var pickAppStep: some View {
        let hasSelection = !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty || !selectedApps.webDomainTokens.isEmpty
        let confirmation = selectionConfirmationText(selection: selectedApps)

        return GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(alignment: .center, spacing: 20) {
                    Text("What should Uncle watch?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.top, max(24, geo.safeAreaInsets.top + 16))

                    VStack(alignment: .center, spacing: 8) {
                        Text("Pick the app that pulls you in.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text("Uncle steps in when you stay too long.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 12)

                    if let confirmation = confirmation {
                        Button {
                            showFamilyPicker = true
                        } label: {
                            Text(confirmation)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Self.accentTeal)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 32)

                VStack(spacing: 20) {
                    onboardingProgressBars(currentStep: 4)
                    Button {
                        if hasSelection {
                            step = 5
                            print("[Uncle] Onboarding – pick app done, step=5 (threshold)")
                            logger.info("Onboarding – step 4 → 5")
                        } else {
                            showFamilyPicker = true
                        }
                    } label: {
                        Text(hasSelection ? "Continue" : "Choose app")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Self.accentTeal)
                    .padding(.horizontal, 4)
                }
                .padding(.bottom, max(24, geo.safeAreaInsets.bottom + 16))
            }
        }
    }

    private var thresholdStep: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(alignment: .center, spacing: 20) {
                    Text("How long is too long?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.top, max(24, geo.safeAreaInsets.top + 16))

                    Text("After this much time, Uncle calls.")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    Picker("Minutes", selection: $thresholdMinutes) {
                        ForEach(1...60, id: \.self) { n in
                            Text("\(n) min").tag(n)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: 200)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 32)

                VStack(spacing: 20) {
                    onboardingProgressBars(currentStep: 5)
                    Button {
                        let clamped = max(1, min(60, thresholdMinutes))
                        UserDefaults.standard.set(String(clamped), forKey: thresholdMinutesKey)
                        thresholdMinutes = clamped
                        step = 6
                        print("[Uncle] Onboarding – threshold=\(clamped) min, step=6 (swearing)")
                        logger.info("Onboarding – threshold \(clamped, privacy: .public) step 5 → 6")
                    } label: {
                        Text("Set limit")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Self.accentTeal)
                    .padding(.horizontal, 4)
                }
                .padding(.bottom, max(24, geo.safeAreaInsets.bottom + 16))
            }
        }
    }

    private var swearingStep: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(alignment: .center, spacing: 20) {
                    Text("Uncle's tone")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.top, max(24, geo.safeAreaInsets.top + 16))

                    VStack(alignment: .center, spacing: 8) {
                        Text("Some reminders are blunt.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text("Decide how honest Uncle should be.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 12)

                    Toggle("Allow swearing", isOn: $allowSwearing)
                        .toggleStyle(.switch)
                        .onChange(of: allowSwearing) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: allowSwearingKey)
                            print("[Uncle] Onboarding – allowSwearing=\(newValue)")
                        }
                        .frame(maxWidth: 280)
                        .padding(.top, 16)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 32)

                VStack(spacing: 20) {
                    onboardingProgressBars(currentStep: 6)
                    Button {
                        UserDefaults.standard.set(allowSwearing, forKey: allowSwearingKey)
                        step = 7
                        print("[Uncle] Onboarding – swearing done, step=7 (goal)")
                        logger.info("Onboarding – step 6 → 7")
                    } label: {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Self.accentTeal)
                    .padding(.horizontal, 4)
                }
                .padding(.bottom, max(24, geo.safeAreaInsets.bottom + 16))
            }
        }
    }

    private static let goalPresets = [
        "Get back to work",
        "Finish what I started",
        "Focus on what matters",
        "Take a break offline",
        "Do the thing I'm avoiding"
    ]
    private var goalStep: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(alignment: .center, spacing: 20) {
                    Text("What should you be doing instead?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.top, max(24, geo.safeAreaInsets.top + 16))

                    VStack(alignment: .center, spacing: 8) {
                        Text("Uncle will remind you when he calls.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text("Pick one.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 12)

                    VStack(spacing: 10) {
                        ForEach(Array(Self.goalPresets.enumerated()), id: \.offset) { index, preset in
                            Button {
                                goalPresetIndex = index
                            } label: {
                                Text(preset)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundStyle(goalPresetIndex == index ? Self.accentTeal : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(goalPresetIndex == index ? Self.accentTeal : Color.gray.opacity(0.3), lineWidth: goalPresetIndex == index ? 2 : 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 32)

                VStack(spacing: 20) {
                    onboardingProgressBars(currentStep: 7)
                    Button {
                        let toSave = goalPresetIndex.map { Self.goalPresets[$0] } ?? ""
                        UserDefaults.standard.set(toSave, forKey: taskTextKey)
                        step = 8
                        print("[Uncle] Onboarding – goal done, step=8 (demo)")
                        logger.info("Onboarding – goal saved, step 7 → 8")
                    } label: {
                        Text("Save reminder")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Self.accentTeal)
                    .padding(.horizontal, 4)
                }
                .padding(.bottom, max(24, geo.safeAreaInsets.bottom + 16))
            }
            .onAppear {
                let saved = UserDefaults.standard.string(forKey: taskTextKey) ?? ""
                goalPresetIndex = Self.goalPresets.firstIndex(of: saved)
            }
        }
    }

    private var demoStep: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(alignment: .center, spacing: 20) {
                    Text("Try it now")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.top, max(24, geo.safeAreaInsets.top + 16))

                    VStack(alignment: .center, spacing: 8) {
                        Text("Send yourself a test call.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text("""
                        When it appears:
                        Tap the notification
                        Answer
                        Listen
                        """)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 32)

                VStack(spacing: 20) {
                    onboardingProgressBars(currentStep: 8)
                    Button {
                        if testCallSent {
                            step = 9
                            print("[Uncle] Onboarding – demo done, step=9 (finish)")
                            logger.info("Onboarding – step 8 → 9")
                        } else {
                            triggerDemoNotification()
                            testCallSent = true
                        }
                    } label: {
                        Text(testCallSent ? "Continue" : "Send test call")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Self.accentTeal)
                    .padding(.horizontal, 4)
                }
                .padding(.bottom, max(24, geo.safeAreaInsets.bottom + 16))
            }
        }
    }

    private var finishStep: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .center, spacing: 20) {
                    Text("You're set")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)

                    VStack(alignment: .center, spacing: 8) {
                        Text("Uncle is watching.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text("When it's time to stop, he'll call.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity)

                Spacer()

                VStack(spacing: 20) {
                    onboardingProgressBars(currentStep: 9)
                    Button {
                        completeOnboarding()
                    } label: {
                        Text("Finish")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Self.accentTeal)
                    .padding(.horizontal, 4)
                }
                .padding(.bottom, max(24, geo.safeAreaInsets.bottom + 16))
            }
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationAuthorized = (settings.authorizationStatus == .authorized)
                print("[Uncle] Onboarding – notification status: \(settings.authorizationStatus.rawValue)")
            }
        }
    }

    private func requestNotificationPermission() {
        print("[Uncle] Onboarding – requestNotificationPermission")
        logger.info("Onboarding – request notifications")
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        DispatchQueue.main.async {
                            notificationAuthorized = granted
                            print("[Uncle] Onboarding – notification permission: granted=\(granted) error=\(String(describing: error))")
                            logger.info("Onboarding – notifications: granted=\(granted, privacy: .public)")
                        }
                    }
                case .denied:
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                        print("[Uncle] Onboarding – opened Settings (notifications denied)")
                    }
                default:
                    notificationAuthorized = (settings.authorizationStatus == .authorized)
                }
            }
        }
    }

    private func requestScreenTimeAuthorization() {
        print("[Uncle] Onboarding – requestScreenTimeAuthorization")
        logger.info("Onboarding – request auth")
        Task {
            do {
                try await authorizationCenter.requestAuthorization(for: .individual)
                print("[Uncle] Onboarding – Screen Time authorization GRANTED")
                logger.info("Onboarding – auth GRANTED")
                await MainActor.run { screenTimeApproved = true }
            } catch {
                print("[Uncle] Onboarding – Screen Time authorization FAILED: \(error)")
                logger.error("Onboarding – auth FAILED: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func saveSelectionAndClosePicker() {
        let hasSelection = !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty || !selectedApps.webDomainTokens.isEmpty
        guard hasSelection else {
            print("[Uncle] Onboarding – no app selected")
            return
        }
        do {
            let data = try JSONEncoder().encode(selectedApps)
            appGroupDefaults?.set(data, forKey: "familyActivitySelection")
            appGroupDefaults?.synchronize()
            print("[Uncle] Onboarding – saved selection to App Group")
            logger.info("Onboarding – saved selection")
        } catch {
            print("[Uncle] Onboarding – failed to encode selection: \(error)")
        }
        showFamilyPicker = false
    }

    private func triggerDemoNotification() {
        print("[Uncle] Onboarding – triggerDemoNotification")
        logger.info("Onboarding – demo notification triggered")
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
        let request = UNNotificationRequest(identifier: demoNotificationID, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Uncle] Onboarding – demo notification FAILED: \(error)")
            } else {
                print("[Uncle] Onboarding – demo notification scheduled – tap it to open Incoming Call")
                logger.info("Onboarding – demo notification scheduled")
            }
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: onboardingCompleteKey)
        UserDefaults.standard.set(false, forKey: "UncleOpenIncomingCallFromNotification")
        let threshold = UserDefaults.standard.string(forKey: thresholdMinutesKey) ?? "1"
        let swearing = UserDefaults.standard.bool(forKey: allowSwearingKey)
        let appCount = selectedApps.applicationTokens.count
        print("[Uncle] Onboarding COMPLETE – threshold=\(threshold)min allowSwearing=\(swearing) targetApps=\(appCount)")
        logger.info("Onboarding complete – threshold=\(threshold, privacy: .public) allowSwearing=\(swearing, privacy: .public) targetApps=\(appCount, privacy: .public)")
        NotificationCenter.default.post(name: .uncleOnboardingComplete, object: nil)
    }
}

