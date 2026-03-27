import Foundation
import Network

/// Monitors network connectivity to enable automatic cloud/local transcription fallback
class NetworkMonitor {
    static let shared = NetworkMonitor()

    // MARK: - Private Properties

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.whispermate.networkmonitor")
    private var _isConnected = true

    // MARK: - Public API

    var isConnected: Bool { _isConnected }

    // MARK: - Initialization

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            self?._isConnected = connected
            DebugLog.info("Network status: \(connected ? "connected" : "disconnected")", context: "NetworkMonitor")
        }
        monitor.start(queue: queue)
    }
}
