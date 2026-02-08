import Foundation

@MainActor
final class UsageStatsStore: ObservableObject {
    @Published private(set) var activeUsers: Int?
    @Published private(set) var isConnected: Bool = false

    private let url: URL
    private let authToken: String?
    private let deviceId: String
    private var task: URLSessionWebSocketTask?
    private var reconnectDelay: TimeInterval = 1
    private var heartbeatTask: Task<Void, Never>?
    private let heartbeatInterval: TimeInterval = 30

    init(
        url: URL = UsageStatsStore.resolveSocketURL(),
        authToken: String? = UsageStatsStore.resolveAuthToken()
    ) {
        self.url = url
        self.authToken = authToken
        self.deviceId = UsageStatsStore.loadDeviceId()
    }

    func start() {
        stop()
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: makeSocketURL())
        self.task = task
        task.resume()
        isConnected = true
        reconnectDelay = 1
        listen()
        startHeartbeatLoop()
        sendHeartbeat()
    }

    func stop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                Task { @MainActor in
                    self.isConnected = false
                    self.scheduleReconnect()
                }
            case .success(let message):
                Task { @MainActor in
                    self.isConnected = true
                    self.handle(message: message)
                    self.listen()
                }
            }
        }
    }

    private func makeSocketURL() -> URL {
        guard let authToken, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "token", value: authToken))
        components.queryItems = items
        return components.url ?? url
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            if let value = parseCount(from: text) {
                activeUsers = value
            }
        case .data(let data):
            if let text = String(data: data, encoding: .utf8),
               let value = parseCount(from: text) {
                activeUsers = value
            }
        @unknown default:
            break
        }
    }

    private func parseCount(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Int(trimmed) {
            return number
        }
        guard let data = trimmed.data(using: .utf8) else { return nil }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let keys = ["active", "activeUsers", "viewers", "count", "users"]
            for key in keys {
                if let value = json[key] as? Int {
                    return value
                }
                if let string = json[key] as? String, let value = Int(string) {
                    return value
                }
            }
        }
        return nil
    }

    private func startHeartbeatLoop() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(heartbeatInterval * 1_000_000_000))
                await self.sendHeartbeat()
            }
        }
    }

    private func sendHeartbeat() {
        guard let task else { return }
        let payload: [String: Any] = {
            var value: [String: Any] = [
                "type": "heartbeat",
                "deviceId": deviceId
            ]
            if let authToken {
                value["token"] = authToken
            }
            return value
        }()
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        task.send(.string(text)) { _ in }
    }

    private func scheduleReconnect() {
        let delay = min(reconnectDelay, 20)
        reconnectDelay = min(reconnectDelay * 2, 20)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.start()
        }
    }

    private static func loadDeviceId() -> String {
        let key = "usage_device_id"
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key) {
            return existing
        }
        let created = UUID().uuidString
        defaults.set(created, forKey: key)
        return created
    }

    private static func resolveAuthToken() -> String? {
        let baked = UsageConfig.authToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let baked, !baked.isEmpty, baked != "REPLACE_ME" {
            return baked
        }
        return ProcessInfo.processInfo.environment["USAGE_AUTH_TOKEN"]
    }

    private static func resolveSocketURL() -> URL {
        if let raw = ProcessInfo.processInfo.environment["USAGE_WS_URL"],
           let url = URL(string: raw) {
            return url
        }
        return UsageConfig.socketURL
    }
}
