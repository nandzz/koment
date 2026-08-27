import Foundation
import notify

public final class ChangeSignal {
    private let name = "com.nandzz.koment.changed"
    private var token: Int32 = NOTIFY_TOKEN_INVALID

    public init() {}

    deinit {
        stop()
    }

    public func post() {
        notify_post(name)
    }

    public func observe(_ handler: @escaping () -> Void) {
        stop()
        notify_register_dispatch(name, &token, .main) { _ in handler() }
    }

    public func stop() {
        guard token != NOTIFY_TOKEN_INVALID else { return }
        notify_cancel(token)
        token = NOTIFY_TOKEN_INVALID
    }
}
