import Foundation

enum Settings {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let cpuLimit = "cpuLimitPercent"
        static let processName = "targetProcessName"
        static let pollInterval = "pollIntervalSeconds"
    }

    static var cpuLimitPercent: Int {
        get {
            let value = defaults.integer(forKey: Key.cpuLimit)
            return (1...99).contains(value) ? value : 20
        }
        set { defaults.set(min(max(newValue, 1), 99), forKey: Key.cpuLimit) }
    }

    static var targetProcessName: String {
        get { defaults.string(forKey: Key.processName) ?? "Adobe crash processor" }
        set { defaults.set(newValue, forKey: Key.processName) }
    }

    static var pollIntervalSeconds: Double {
        get {
            let value = defaults.double(forKey: Key.pollInterval)
            return value >= 1 ? value : 5
        }
        set { defaults.set(max(newValue, 1), forKey: Key.pollInterval) }
    }
}
