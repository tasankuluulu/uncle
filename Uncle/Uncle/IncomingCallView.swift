import SwiftUI
import AVFoundation
import ManagedSettings
import UIKit
import os

private let accentTeal = Color(red: 0.11, green: 0.27, blue: 0.35)

/// Resolve audio URL from bundle (tries subdirectory then root — Xcode copy behavior varies).
private func urlForAudio(name: String, ext: String) -> URL? {
    let subdirs = ["Resources/Audio", "Audio", nil] as [String?]
    for sub in subdirs {
        let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: sub)
        if let u = url, (try? u.checkResourceIsReachable()) == true { return u }
    }
    return Bundle.main.url(forResource: name, withExtension: ext)
}

struct IncomingCallView: View {
    @Environment(\.dismiss) private var dismiss
    var isCallPresented: (() -> Bool)? = nil
    var isDemo: Bool = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioDelegate: AudioFinishDelegate?
    @State private var ringingPlayer: AVAudioPlayer?
    private let logger = Logger(subsystem: "uncle.app.v3", category: "IncomingCallView")

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.15),
                        Color(red: 0.08, green: 0.18, blue: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Caller info card
                    VStack(spacing: 20) {
                        // Avatar circle
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [accentTeal.opacity(0.3), accentTeal.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 50, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .shadow(color: accentTeal.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        // Caller name (always "Uncle" — the caller is Uncle, not the user)
                        Text("Uncle")
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        // Status text
                        Text("Incoming call")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.vertical, 40)
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 32) {
                        // Decline button
                        Button(action: declineTapped) {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.2))
                                        .frame(width: 72, height: 72)
                                    Image(systemName: "phone.down.fill")
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundStyle(.red)
                                }
                                Text("Decline")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // Answer button
                        Button(action: answerTapped) {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.green.opacity(0.3), Color.green.opacity(0.5)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 72, height: 72)
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundStyle(.green)
                                }
                                Text("Answer")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, max(40, geo.safeAreaInsets.bottom + 20))
                }
            }
        }
        .onAppear {
            print("[Uncle] IncomingCallView – screen appeared")
            logger.info("IncomingCallView – screen appeared")
            startRinging()
        }
        .onDisappear {
            stopRinging()
            audioPlayer?.stop()
            audioPlayer = nil
            audioDelegate = nil
        }
    }

    private func answerTapped() {
        print("[Uncle] IncomingCallView – answer tapped")
        logger.info("IncomingCallView – answer tapped")
        stopRinging()
        let defaults = UserDefaults(suiteName: UncleAppState.appGroupID)
        let oldState = UncleAppState.read(from: defaults)
        UncleAppState.write(UncleAppState.inCall, to: defaults)
        print("[Uncle] STATE UI: \(oldState) → \(UncleAppState.inCall) (Answer)")
        logger.info("STATE UI: \(oldState, privacy: .public) → \(UncleAppState.inCall, privacy: .public) (Answer)")
        startAudio()
    }

    private func declineTapped() {
        stopRinging()
        audioPlayer?.stop()
        audioPlayer = nil
        audioDelegate = nil

        if isDemo {
            print("[Uncle] IncomingCallView – decline tapped (demo, inconsequential)")
            logger.info("IncomingCallView – decline (demo) – no state change")
            dismiss()
            return
        }

        print("[Uncle] IncomingCallView – decline tapped (no timer, shield stays)")
        logger.info("IncomingCallView – decline action – shield stays, no cooldown")
        let defaults = UserDefaults(suiteName: UncleAppState.appGroupID)
        UncleAppState.write(UncleAppState.lockedPendingCall, to: defaults)
        UncleAppState.writeCooldownUntil(nil, to: defaults)
        print("[Uncle] STATE UI: → locked_pending_call (Decline) – Call Uncle button will appear")
        logger.info("STATE UI: → locked_pending_call (Decline)")
        dismiss()
    }

    private func startRinging() {
        guard let url = urlForAudio(name: "uncle_ringing", ext: "caf") else {
            print("[Uncle] IncomingCallView – uncle_ringing.caf not found in bundle")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.play()
            ringingPlayer = player
            print("[Uncle] IncomingCallView – ringing started")
            logger.info("IncomingCallView – ringing started")
        } catch {
            print("[Uncle] IncomingCallView – ringing failed: \(error)")
        }
    }

    private func stopRinging() {
        ringingPlayer?.stop()
        ringingPlayer = nil
    }

    private func startAudio() {
        let defaults = UserDefaults(suiteName: UncleAppState.appGroupID)
        let (level, reason) = UncleStrikeLevel.effectiveLevel(from: defaults)
        let bucket = UncleStrikeLevel.bucketNames[min(level, UncleStrikeLevel.bucketNames.count - 1)]
        let filename = UncleStrikeLevel.audioFileName(for: level)
        print("[Uncle] IncomingCallView – strike level=\(level) reason=\(reason) bucket=\(bucket) audio=\(filename).mp3")
        logger.info("IncomingCallView – strike=\(level, privacy: .public) bucket=\(bucket, privacy: .public) audio=\(filename, privacy: .public)")
        guard let url = urlForAudio(name: filename, ext: "mp3") else {
            print("[Uncle] IncomingCallView – \(filename).mp3 not found in bundle")
            logger.error("IncomingCallView – \(filename, privacy: .public).mp3 not found in bundle")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            print("[Uncle] IncomingCallView – audio session configured for playback")
            let player = try AVAudioPlayer(contentsOf: url)
            let isCallPresentedRef = isCallPresented
            let dismissRef = dismiss
            let delegate = AudioFinishDelegate(onFinish: {
                let stateLogger = Logger(subsystem: "uncle.app.v3", category: "IncomingCallView")
                print("[Uncle] IncomingCallView – PLAYBACK_FINISHED")
                stateLogger.info("IncomingCallView – PLAYBACK_FINISHED")

                let appActive = UIApplication.shared.applicationState == .active
                let callPresented = isCallPresentedRef?() ?? true
                let conditionsPassed = appActive && callPresented
                print("[Uncle] IncomingCallView – unlock conditions: appActive=\(appActive) callPresented=\(callPresented) → passed=\(conditionsPassed)")
                stateLogger.info("unlock conditions: appActive=\(appActive, privacy: .public) callPresented=\(callPresented, privacy: .public) passed=\(conditionsPassed, privacy: .public)")

                if conditionsPassed {
                    let store = ManagedSettingsStore()
                    store.shield.applications = nil
                    store.shield.applicationCategories = nil
                    store.shield.webDomains = nil
                    print("[Uncle] IncomingCallView – shield cleared SUCCESS, posting restart monitoring")
                    stateLogger.info("shield cleared SUCCESS – restart monitoring")
                    NotificationCenter.default.post(name: .uncleRestartMonitoring, object: nil)
                } else {
                    print("[Uncle] IncomingCallView – conditions not passed, shield NOT cleared")
                    stateLogger.info("conditions not passed – shield NOT cleared")
                }

                let defaults = UserDefaults(suiteName: UncleAppState.appGroupID)
                let oldState = UncleAppState.read(from: defaults)
                UncleAppState.write(UncleAppState.idle, to: defaults)
                print("[Uncle] STATE UI: \(oldState) → \(UncleAppState.idle) (playback finished)")
                stateLogger.info("STATE UI: \(oldState, privacy: .public) → \(UncleAppState.idle, privacy: .public) (playback finished)")

                if conditionsPassed {
                    DispatchQueue.main.async {
                        dismissRef()
                    }
                }
            })
            player.delegate = delegate
            audioDelegate = delegate
            player.play()
            audioPlayer = player
            print("[Uncle] IncomingCallView – audio started")
            logger.info("IncomingCallView – audio started")
        } catch {
            print("[Uncle] IncomingCallView – audio failed: \(error)")
            logger.error("IncomingCallView – audio failed: \(String(describing: error), privacy: .public)")
        }
    }
}

private class AudioFinishDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
