import Foundation

enum HelperError: LocalizedError {
    case unavailable(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message): return "Helper is not reachable (\(message))."
        case .failed(let message): return message
        }
    }

    var isUnavailable: Bool {
        if case .unavailable = self { return true }
        return false
    }
}

/// Resumes a continuation exactly once, whichever XPC callback fires first.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func run(_ body: () -> Void) {
        lock.lock()
        if done { lock.unlock(); return }
        done = true
        lock.unlock()
        body()
    }
}

/// Thin async client for the privileged helper. Used by the app, the
/// Control Center extension and the CLI.
enum HelperClient {
    static func status() async throws -> KeepAwakeStatus {
        try await call { proxy, reply in proxy.getStatus(reply: reply) }
    }

    static func setKeepAwake(_ enabled: Bool, duration: TimeInterval? = nil) async throws -> KeepAwakeStatus {
        try await call { proxy, reply in
            proxy.setKeepAwake(enabled, durationSeconds: duration ?? 0, reply: reply)
        }
    }

    static func setBatteryThreshold(_ percent: Int?) async throws -> KeepAwakeStatus {
        try await call { proxy, reply in
            proxy.setBatteryThreshold(percent ?? 0, reply: reply)
        }
    }

    private static func call(
        _ body: @escaping (HelperProtocol, @escaping (Data?, String?) -> Void) -> Void
    ) async throws -> KeepAwakeStatus {
        try await withCheckedThrowingContinuation { continuation in
            let connection = NSXPCConnection(machServiceName: SAlive.helperMachService, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
            // Make sure we are talking to *our* helper, not an impostor.
            connection.setCodeSigningRequirement(SAlive.codeSigningRequirement)

            let once = Once()
            let finish: (Result<KeepAwakeStatus, Error>) -> Void = { result in
                once.run { continuation.resume(with: result) }
                connection.invalidate()
            }
            connection.invalidationHandler = {
                finish(.failure(HelperError.unavailable("connection invalidated")))
            }
            connection.interruptionHandler = {
                finish(.failure(HelperError.unavailable("connection interrupted")))
            }
            connection.resume()

            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                finish(.failure(HelperError.unavailable(error.localizedDescription)))
            }
            guard let helper = proxy as? HelperProtocol else {
                finish(.failure(HelperError.unavailable("bad proxy")))
                return
            }
            body(helper) { data, message in
                if let message {
                    finish(.failure(HelperError.failed(message)))
                } else if let data, let status = try? JSONDecoder().decode(KeepAwakeStatus.self, from: data) {
                    finish(.success(status))
                } else {
                    finish(.failure(HelperError.failed("Invalid response from helper.")))
                }
            }
        }
    }
}
