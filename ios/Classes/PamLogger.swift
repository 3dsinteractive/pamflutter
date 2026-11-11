import Flutter
import Foundation
import os.log

// OSLog supports the plugin's iOS 13 deployment target.
final class PamLogger {
    private var logs: [String: OSLog] = [:]
    private var enabled = false

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "configure" {
            let args = call.arguments as? [String: Any] ?? [:]
            enabled = args["enabled"] as? Bool ?? false
            result(nil)
            return
        }
        guard call.method == "log" else {
            result(FlutterMethodNotImplemented)
            return
        }
        let args = call.arguments as? [String: Any] ?? [:]
        let category = args["category"] as? String ?? "General"
        let level = args["level"] as? String ?? "info"
        let lines = args["lines"] as? [String] ?? []
        // Dart gates its own entries; native pixel diagnostics use enabled.
        write(category: category, level: level, lines: lines)
        result(nil)
    }

    func attentionPixelFailed(status: Int?, error: Error?) {
        guard enabled, error != nil || (status ?? 0) >= 400 else { return }
        write(category: "Attention", level: "error", lines: [
            "Tracking pixel failed status=\(status.map { String($0) } ?? "none") error=\(error?.localizedDescription ?? "HTTP error")"
        ])
    }

    private func write(category: String, level: String, lines: [String]) {
        let log = logs[category] ?? OSLog(subsystem: "ai.pams.flutter", category: category)
        logs[category] = log
        let type: OSLogType
        switch level {
        case "debug": type = .debug
        case "warning": type = .default
        case "error": type = .error
        default: type = .info
        }
        let label = level == "warning" ? "WARN" : level.uppercased()
        for text in lines {
            for line in text.components(separatedBy: .newlines) {
                var chunk = ""
                var bytes = 0
                for scalar in line.unicodeScalars {
                    let character = String(scalar)
                    if bytes + character.utf8.count > 800 {
                        os_log("%{public}@", log: log, type: type, "[PAM][\(category)][\(label)] \(chunk)")
                        chunk = ""
                        bytes = 0
                    }
                    chunk += character
                    bytes += character.utf8.count
                }
                os_log("%{public}@", log: log, type: type, "[PAM][\(category)][\(label)] \(chunk)")
            }
        }
    }
}
