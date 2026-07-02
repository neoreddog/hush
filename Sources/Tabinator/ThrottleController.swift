import Foundation

/// Owns the poll loop: finds target processes, attaches throttlers,
/// detects PID changes/reuse, and cleans up throttlers whose process
/// has gone away.
final class ThrottleController {
    private(set) var throttlers: [pid_t: CPUThrottler] = [:]
    private var pollTimer: Timer?

    /// Called on the main thread whenever the set of throttled PIDs changes.
    var onStatusChange: (() -> Void)?

    var isRunning: Bool { pollTimer != nil }

    func start() {
        guard pollTimer == nil else { return }
        poll()
        let timer = Timer(timeInterval: Settings.pollIntervalSeconds, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        releaseAll()
    }

    /// Re-applies the current CPU limit to all attached throttlers.
    func limitChanged() {
        let limit = Settings.cpuLimitPercent
        for throttler in throttlers.values {
            throttler.apply(limitPercent: limit)
        }
    }

    /// Switches to a new target: releases everything attached to the old
    /// name and immediately scans for the new one.
    func retarget() {
        releaseAll()
        poll()
    }

    /// Detaches every throttler, leaving all processes running.
    func releaseAll() {
        for throttler in throttlers.values {
            throttler.release()
        }
        if !throttlers.isEmpty {
            throttlers.removeAll()
            onStatusChange?()
        }
    }

    private func poll() {
        let name = Settings.targetProcessName
        var changed = false

        // Drop throttlers whose PID died or was reused by another process.
        for (pid, throttler) in throttlers where !ProcessMonitor.pid(pid, isStillNamed: name) {
            throttler.release()
            throttlers.removeValue(forKey: pid)
            changed = true
        }

        // Attach to any new instances of the target.
        for pid in ProcessMonitor.findPIDs(named: name) where throttlers[pid] == nil {
            let throttler = CPUThrottler(pid: pid)
            throttler.apply(limitPercent: Settings.cpuLimitPercent)
            throttlers[pid] = throttler
            changed = true
        }

        if changed { onStatusChange?() }
    }
}
