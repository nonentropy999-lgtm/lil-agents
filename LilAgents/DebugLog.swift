import Foundation

enum DebugLog {
    private static let logURL = URL(fileURLWithPath: "/tmp/travis_agents_debug.log")

    static func write(_ message: String) {
        let formatter = ISO8601DateFormatter()
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                    return
                }
            }
            try? data.write(to: logURL)
        }
    }
}
