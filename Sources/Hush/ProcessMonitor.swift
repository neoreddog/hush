import Foundation
import Darwin

/// Locates processes by name and verifies that a PID still belongs to the
/// expected process (guarding against PID reuse).
enum ProcessMonitor {

    /// Returns the PIDs of all running processes whose name matches
    /// `name` (case-insensitive).
    static func findPIDs(named name: String) -> [pid_t] {
        var size: size_t = 0
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0 else { return [] }

        let stride = MemoryLayout<kinfo_proc>.stride
        // Leave headroom for processes spawned between the two sysctl calls.
        size += stride * 16
        var count = size / stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return [] }
        count = size / stride

        var pids: [pid_t] = []
        for i in 0..<count {
            let pid = procs[i].kp_proc.p_pid
            guard pid > 0 else { continue }
            if processName(of: pid)?.caseInsensitiveCompare(name) == .orderedSame {
                pids.append(pid)
            }
        }
        return pids
    }

    /// Full executable name for a PID (not truncated to 16 chars like p_comm).
    static func processName(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        let path = String(cString: buffer)
        return (path as NSString).lastPathComponent
    }

    /// Running processes aggregated by executable name with their combined
    /// CPU usage, sorted busiest-first. Used to populate the picker menu.
    static func runningProcessesByCPU() -> [(name: String, cpu: Double)] {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-axco", "%cpu=,comm="]
        let pipe = Pipe()
        ps.standardOutput = pipe
        guard (try? ps.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        ps.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var totals: [String: Double] = [:]
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let space = trimmed.firstIndex(of: " ") else { continue }
            let cpu = Double(trimmed[..<space]) ?? 0
            let name = trimmed[trimmed.index(after: space)...].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            totals[name, default: 0] += cpu
        }
        return totals
            .map { (name: $0.key, cpu: $0.value) }
            .sorted { $0.cpu == $1.cpu ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending : $0.cpu > $1.cpu }
    }

    /// True if `pid` is alive and still runs a process with the given name.
    static func pid(_ pid: pid_t, isStillNamed name: String) -> Bool {
        guard kill(pid, 0) == 0 || errno == EPERM else { return false }
        return processName(of: pid)?.caseInsensitiveCompare(name) == .orderedSame
    }
}
