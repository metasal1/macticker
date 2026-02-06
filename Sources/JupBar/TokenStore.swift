import Combine
import Foundation
import AppKit

@MainActor
final class TokenStore: ObservableObject {
    @Published var configs: [TokenConfig] = []
    @Published private(set) var quotes: [TokenQuote] = []
    @Published private(set) var rpcURL: String
    @Published private(set) var scrollSpeed: Double
    @Published private(set) var alertThresholdPercent: Double

    private let defaultsKey = "jupbar.tokens"
    private let rpcKey = "jupbar.rpcURL"
    private let speedKey = "jupbar.scrollSpeed"
    private let alertKey = "jupbar.alertThresholdPercent"
    private var timer: Timer?
    private var api: HeliusAPI
    private var priceHistory: [String: [PricePoint]] = [:]
    private var lastAlertedAt: [String: Date] = [:]
    private let alertCooldown: TimeInterval = 600

    init() {
        let savedRPC = UserDefaults.standard.string(forKey: rpcKey)
        let defaultRPC = "https://viviyan-bkj12u-fast-mainnet.helius-rpc.com"
        let resolvedRPC = savedRPC?.isEmpty == false ? savedRPC! : defaultRPC
        let savedSpeed = UserDefaults.standard.double(forKey: speedKey)
        self.scrollSpeed = savedSpeed > 0 ? savedSpeed : 40
        let savedAlert = UserDefaults.standard.double(forKey: alertKey)
        self.alertThresholdPercent = savedAlert > 0 ? savedAlert : 5
        self.rpcURL = resolvedRPC
        self.api = HeliusAPI(rpcURL: resolvedRPC)
        load()
    }

    func startPolling() {
        stopPolling()
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func addMint(_ mint: String) {
        let clean = mint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard !configs.contains(where: { $0.mint == clean }) else { return }
        let config = TokenConfig(mint: clean, symbol: shortSymbol(for: clean), pinned: false)
        configs.append(config)
        persist()
        Task { await refresh() }
    }

    func addMints(_ mints: [String]) {
        let cleaned = mints
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            .filter { !$0.isEmpty }
        let existing = Set(configs.map { $0.mint })
        let unique = cleaned.filter { !existing.contains($0) }
        guard !unique.isEmpty else { return }
        let newConfigs = unique.map { TokenConfig(mint: $0, symbol: shortSymbol(for: $0), pinned: false) }
        configs.append(contentsOf: newConfigs)
        persist()
        Task { await refresh() }
    }

    func removeMint(_ mint: String) {
        let clean = mint.trimmingCharacters(in: .whitespacesAndNewlines)
        configs.removeAll { $0.mint == clean }
        persist()
        Task { await refresh() }
    }

    func moveConfigs(from offsets: IndexSet, to destination: Int) {
        configs.move(fromOffsets: offsets, toOffset: destination)
        persist()
    }

    func sortConfigsAlphabetically() {
        configs.sort { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }
            return lhs.symbol.lowercased() < rhs.symbol.lowercased()
        }
        persist()
    }

    func togglePinned(for mint: String) {
        guard let index = configs.firstIndex(where: { $0.mint == mint }) else { return }
        configs[index].pinned.toggle()
        persist()
    }

    func updateRPCURL(_ url: String) {
        let clean = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        rpcURL = clean
        UserDefaults.standard.set(clean, forKey: rpcKey)
        api = HeliusAPI(rpcURL: clean)
        Task { await refresh() }
    }

    func updateScrollSpeed(_ speed: Double) {
        let clamped = max(10, min(speed, 160))
        scrollSpeed = clamped
        UserDefaults.standard.set(clamped, forKey: speedKey)
    }

    func updateAlertThreshold(_ thresholdPercent: Double) {
        let clamped = max(0.5, min(thresholdPercent, 50))
        alertThresholdPercent = clamped
        UserDefaults.standard.set(clamped, forKey: alertKey)
    }

    func importCSV(_ content: String) {
        let lines = content
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var mints: [String] = []
        for (index, line) in lines.enumerated() {
            if index == 0 && line.lowercased().contains("mint") {
                continue
            }
            let parts = line
                .split(separator: ",", omittingEmptySubsequences: true)
                .flatMap { $0.split(separator: "\t", omittingEmptySubsequences: true) }
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if let mint = parts.first(where: { isProbablyMint($0) }) {
                mints.append(mint)
            } else if let first = parts.first {
                mints.append(first)
            }
        }
        addMints(mints)
    }

    func addPastedMints(_ raw: String) {
        let parts = raw
            .replacingOccurrences(of: "\r", with: "\n")
            .split { $0 == "\n" || $0 == "," || $0 == " " || $0 == "\t" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        addMints(parts)
    }

    func exportCSV() -> String {
        var rows = ["mint"]
        rows.append(contentsOf: configs.map { $0.mint })
        return rows.joined(separator: "\n")
    }

    private func refresh() async {
        guard !configs.isEmpty else {
            quotes = []
            return
        }
        let mints = configs.map { $0.mint }
        let data = await api.fetchQuotes(mints: mints)
        let now = Date()
        let merged = configs.map { config -> TokenQuote in
            if var quote = data[config.mint] {
                let change1h = updateHistory(mint: config.mint, price: quote.price, now: now)
                maybePlayAlert(mint: config.mint, change1h: change1h, now: now)
                quote = TokenQuote(
                    mint: quote.mint,
                    symbol: quote.symbol,
                    name: quote.name,
                    price: quote.price,
                    change1h: change1h,
                    volume1h: nil,
                    iconURL: quote.iconURL
                )
                return quote
            }
            return TokenQuote(
                mint: config.mint,
                symbol: config.symbol,
                name: nil,
                price: nil,
                change1h: nil,
                volume1h: nil,
                iconURL: nil
            )
        }
        quotes = merged
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([TokenConfig].self, from: data),
              !decoded.isEmpty else {
            configs = DefaultTokens.tokens
            persist()
            return
        }
        configs = decoded.map { config in
            if config.symbol.isEmpty {
                return TokenConfig(mint: config.mint, symbol: shortSymbol(for: config.mint), pinned: false)
            }
            return config
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func shortSymbol(for mint: String) -> String {
        let prefix = mint.prefix(4)
        return String(prefix).uppercased()
    }

    private func isProbablyMint(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        guard trimmed.count >= 32 && trimmed.count <= 44 else { return false }
        let allowed = CharacterSet(charactersIn: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func updateHistory(mint: String, price: Double?, now: Date) -> Double? {
        guard let price else { return nil }
        var history = priceHistory[mint] ?? []
        history.append(PricePoint(time: now, price: price))
        let cutoff = now.addingTimeInterval(-3600)
        history = history.filter { $0.time >= cutoff }
        priceHistory[mint] = history
        guard let first = history.first else { return nil }
        guard first.price > 0 else { return nil }
        return (price - first.price) / first.price
    }

    private func maybePlayAlert(mint: String, change1h: Double?, now: Date) {
        guard let change1h else { return }
        let threshold = max(0.5, alertThresholdPercent)
        let percentMove = abs(change1h) * 100
        guard percentMove >= threshold else { return }
        if let last = lastAlertedAt[mint], now.timeIntervalSince(last) < alertCooldown {
            return
        }
        lastAlertedAt[mint] = now
        NSSound.beep()
    }
}

enum DefaultTokens {
    static let tokens: [TokenConfig] = [
        // TODO: Replace with real mints for SOL, JUP, MET, BONK, PAYAI, RADR.
    ]
}

private struct PricePoint {
    let time: Date
    let price: Double
}
