import Foundation

struct Request {
    let id: Any?
    let method: String
    let params: [String: Any]

    var isNotification: Bool {
        switch id {
        case .none: return true
        case .some: return false
        }
    }
}

struct Transport {
    func read() -> Request? {
        while let line = readLine(strippingNewline: true) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard
                let data = trimmed.data(using: .utf8),
                let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let method = message["method"] as? String
            else {
                log("dropped a line that is not a JSON-RPC request")
                continue
            }
            let identifier = message["id"]
            return Request(
                id: identifier is NSNull ? .none : identifier,
                method: method,
                params: message["params"] as? [String: Any] ?? [:]
            )
        }
        return .none
    }

    func reply(to request: Request, result: [String: Any]) {
        guard let id = request.id else { return }
        send(["jsonrpc": "2.0", "id": id, "result": result])
    }

    func fail(_ request: Request, code: Int, message: String) {
        guard let id = request.id else { return }
        send(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]])
    }

    func log(_ message: String) {
        FileHandle.standardError.write(Data("koment: \(message)\n".utf8))
    }

    private func send(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message, options: []) else {
            log("could not encode a reply")
            return
        }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
