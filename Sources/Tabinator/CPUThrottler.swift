import Foundation
import Darwin

/// Caps a process's CPU usage by duty-cycling it with SIGSTOP/SIGCONT
/// (the same technique as `cpulimit`). Within each 100 ms window the
/// process runs for `limit%` of the time and is stopped for the rest.
///
/// Always call `release()` (or let the throttler notice the process died)
/// so the target is never left stopped.
final class CPUThrottler {
    let pid: pid_t
    private let queue = DispatchQueue(label: "tabinator.throttler", qos: .userInitiated)
    private var timer: DispatchSourceTimer?
    private var stopped = false
    private var released = false

    private static let windowMs = 100

    init(pid: pid_t) {
        self.pid = pid
    }

    deinit {
        release()
    }

    /// Starts (or re-tunes) the duty cycle for the given percentage limit.
    func apply(limitPercent: Int) {
        let runMs = min(max(limitPercent, 1), 99) * Self.windowMs / 100
        let sleepMs = Self.windowMs - runMs

        queue.sync {
            timer?.cancel()
            guard !released else { return }

            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(Self.windowMs), leeway: .milliseconds(5))
            timer.setEventHandler { [weak self] in
                guard let self, !self.released else { return }
                // Run phase.
                if self.stopped {
                    kill(self.pid, SIGCONT)
                    self.stopped = false
                }
                // Stop phase, scheduled within the same window.
                self.queue.asyncAfter(deadline: .now() + .milliseconds(runMs)) { [weak self] in
                    guard let self, !self.released else { return }
                    if sleepMs > 0, kill(self.pid, SIGSTOP) == 0 {
                        self.stopped = true
                    }
                }
            }
            self.timer = timer
            timer.resume()
        }
    }

    /// Stops throttling and makes sure the process is left running.
    func release() {
        queue.sync {
            guard !released else { return }
            released = true
            timer?.cancel()
            timer = nil
            kill(pid, SIGCONT)
            stopped = false
        }
    }
}
