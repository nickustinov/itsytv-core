import os.log

public enum ItsytvCoreLog {
    /// Set to `true` to enable verbose logging from ItsytvCore.
    public static var verbose = false
}

/// Logger wrapper that respects the verbose flag for info/debug messages.
struct CoreLog {
    private let logger: Logger

    init(category: String) {
        logger = Logger(subsystem: "com.itsytv.app", category: category)
    }

    func info(_ message: String) {
        guard ItsytvCoreLog.verbose else { return }
        logger.info("\(message, privacy: .public)")
    }

    func debug(_ message: String) {
        guard ItsytvCoreLog.verbose else { return }
        logger.debug("\(message, privacy: .public)")
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
