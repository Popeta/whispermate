import Foundation

// MARK: - File Logger

/// Handles writing logs to file for diagnostics in Release builds
private class FileLogger {
    static let shared = FileLogger()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.whispermate.filelogger", qos: .utility)
    private let maxFileSize: Int64 = 5 * 1024 * 1024 // 5MB
    private let dateFormatter: ISO8601DateFormatter

    private init() {
        // Create log directory
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/WhisperMate", isDirectory: true)

        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        self.fileURL = logsDir.appendingPathComponent("whispermate.log")

        self.dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    var logFileURL: URL { fileURL }

    func write(_ level: String, _ message: String, context: String?) {
        queue.async { [self] in
            // Check file size and rotate if needed
            rotateIfNeeded()

            let timestamp = dateFormatter.string(from: Date())
            let contextPart = context.map { "[\($0)] " } ?? ""
            let line = "\(timestamp) [\(level)] \(contextPart)\(message)\n"

            // Append to file
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    if let handle = try? FileHandle(forWritingTo: fileURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        try? handle.close()
                    }
                } else {
                    try? data.write(to: fileURL)
                }
            }
        }
    }

    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int64,
              size > maxFileSize else {
            return
        }

        // Rename old log and start fresh
        let backupURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("whispermate.log.old")
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.moveItem(at: fileURL, to: backupURL)
    }
}

// MARK: - Debug Log

/// Debug logging utility that only logs in DEBUG builds
/// Automatically strips all logging from Release builds for privacy and security
/// Error level always writes to file for diagnostics
struct DebugLog {

    /// UserDefaults key for file logging toggle
    private static let fileLoggingKey = "debugFileLoggingEnabled"

    /// Whether file logging is enabled (for non-error logs)
    static var isFileLoggingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: fileLoggingKey) }
        set { UserDefaults.standard.set(newValue, forKey: fileLoggingKey) }
    }

    /// URL to the log file for diagnostics
    static var logFileURL: URL { FileLogger.shared.logFileURL }

    /// Log a general debug message
    static func log(_ items: Any..., separator: String = " ", file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        let message = items.map { "\($0)" }.joined(separator: separator)

        #if DEBUG
        print("[\(filename):\(line)] \(message)")
        #endif

        if isFileLoggingEnabled {
            FileLogger.shared.write("DEBUG", "[\(filename):\(line)] \(message)", context: nil)
        }
    }

    /// Log an info message with context
    static func info(_ items: Any..., separator: String = " ", context: String? = nil) {
        let message = items.map { "\($0)" }.joined(separator: separator)

        #if DEBUG
        if let context = context {
            print("ℹ️ [\(context)] \(message)")
        } else {
            print("ℹ️ \(message)")
        }
        #endif

        if isFileLoggingEnabled {
            FileLogger.shared.write("INFO", message, context: context)
        }
    }

    /// Log a warning message
    static func warning(_ items: Any..., separator: String = " ", context: String? = nil) {
        let message = items.map { "\($0)" }.joined(separator: separator)

        #if DEBUG
        if let context = context {
            print("⚠️ [\(context)] \(message)")
        } else {
            print("⚠️ \(message)")
        }
        #endif

        if isFileLoggingEnabled {
            FileLogger.shared.write("WARN", message, context: context)
        }
    }

    /// Log an error message (always logs to console and ALWAYS writes to file for diagnostics)
    static func error(_ items: Any..., separator: String = " ", context: String? = nil) {
        let message = items.map { "\($0)" }.joined(separator: separator)
        if let context = context {
            print("❌ [\(context)] \(message)")
        } else {
            print("❌ \(message)")
        }

        // Always write errors to file (regardless of setting)
        FileLogger.shared.write("ERROR", message, context: context)
    }

    /// Log sensitive data (only in DEBUG, never in Release)
    static func sensitive(_ items: Any..., separator: String = " ", context: String? = nil) {
        #if DEBUG
        let message = items.map { "\($0)" }.joined(separator: separator)
        if let context = context {
            print("🔒 [SENSITIVE][\(context)] \(message)")
        } else {
            print("🔒 [SENSITIVE] \(message)")
        }
        #endif
        // Never log sensitive data to file
    }

    /// Log API-related information (only in DEBUG)
    static func api(_ items: Any..., separator: String = " ", endpoint: String? = nil) {
        let message = items.map { "\($0)" }.joined(separator: separator)

        #if DEBUG
        if let endpoint = endpoint {
            print("🌐 [API][\(endpoint)] \(message)")
        } else {
            print("🌐 [API] \(message)")
        }
        #endif

        if isFileLoggingEnabled {
            FileLogger.shared.write("API", message, context: endpoint)
        }
    }

    /// Log pipeline events (always logged to file when file logging is enabled)
    static func pipeline(_ message: String) {
        #if DEBUG
        print("[PIPELINE] \(message)")
        #endif

        if isFileLoggingEnabled {
            FileLogger.shared.write("PIPELINE", message, context: nil)
        }
    }
}
