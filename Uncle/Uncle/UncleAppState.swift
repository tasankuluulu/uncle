import Foundation

/// Persisted app state for foreground routing. Stored in App Group.
enum UncleAppState {
    static let appGroupID = "group.uncle.app.v3"
    static let storageKey = "uncleAppState"
    static let cooldownUntilKey = "uncleCooldownUntil"

    static let idle = "idle"
    static let lockedPendingCall = "locked_pending_call"
    static let inCall = "in_call"
    static let declineCooldown = "decline_cooldown"

    static func read(from defaults: UserDefaults?) -> String {
        defaults?.string(forKey: storageKey) ?? idle
    }

    static func write(_ value: String, to defaults: UserDefaults?) {
        defaults?.set(value, forKey: storageKey)
        defaults?.synchronize()
    }

    static func readCooldownUntil(from defaults: UserDefaults?) -> Date? {
        let raw = defaults?.double(forKey: cooldownUntilKey)
        guard let t = raw, t > 0 else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    static func writeCooldownUntil(_ date: Date?, to defaults: UserDefaults?) {
        defaults?.set(date?.timeIntervalSince1970 ?? 0, forKey: cooldownUntilKey)
        defaults?.synchronize()
    }

    static let strikeLevelKey = "uncleStrikeLevel"
    static let lastLockAtKey = "uncleLastLockAt"
    static let strikeCap = 3
    static let decayHours = 4.0

    static func readStrikeLevel(from defaults: UserDefaults?) -> Int {
        let raw = defaults?.integer(forKey: strikeLevelKey) ?? 0
        return max(0, min(strikeCap, raw))
    }

    static func writeStrikeLevel(_ level: Int, to defaults: UserDefaults?) {
        let capped = max(0, min(strikeCap, level))
        defaults?.set(capped, forKey: strikeLevelKey)
        defaults?.synchronize()
    }

    static func readLastLockAt(from defaults: UserDefaults?) -> Date? {
        let raw = defaults?.double(forKey: lastLockAtKey) ?? 0
        guard raw > 0 else { return nil }
        return Date(timeIntervalSince1970: raw)
    }

    static func writeLastLockAt(_ date: Date?, to defaults: UserDefaults?) {
        defaults?.set(date?.timeIntervalSince1970 ?? 0, forKey: lastLockAtKey)
        defaults?.synchronize()
    }
}

/// Strike level with decay and midnight reset. Returns effective level and reason for logging.
enum UncleStrikeLevel {
    static func effectiveLevel(from defaults: UserDefaults?) -> (level: Int, reason: String) {
        let raw = UncleAppState.readStrikeLevel(from: defaults)
        let lastLock = UncleAppState.readLastLockAt(from: defaults)
        let now = Date()

        if let last = lastLock {
            let calendar = Calendar.current
            if !calendar.isDate(last, inSameDayAs: now) {
                print("[Uncle] strike midnight reset – lastLock \(last) not same day as now \(now)")
                UncleAppState.writeStrikeLevel(0, to: defaults)
                UncleAppState.writeLastLockAt(nil, to: defaults)
                return (0, "midnight_reset")
            }
            let hoursSince = now.timeIntervalSince(last) / 3600
            if hoursSince >= UncleAppState.decayHours {
                let decayed = max(0, raw - 1)
                UncleAppState.writeStrikeLevel(decayed, to: defaults)
                print("[Uncle] strike decay – \(hoursSince)h since last lock, \(raw) → \(decayed)")
                return (decayed, "decay_4h")
            }
        }
        return (raw, "none")
    }

    static func levelForAudio(from defaults: UserDefaults?) -> Int {
        effectiveLevel(from: defaults).level
    }

    static let bucketNames = ["calm", "concerned", "irritated", "disappointed"]
    static let audioFiles = ["greeting_call_0", "first_call_0", "greeting_call_0", "first_call_0"]

    static func audioFileName(for level: Int) -> String {
        let idx = min(level, audioFiles.count - 1)
        return audioFiles[max(0, idx)]
    }
}
