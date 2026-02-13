import Combine
import Foundation
import AppKit

@MainActor
final class TokenStore: ObservableObject {
    @Published var configs: [TokenConfig] = []
    @Published private(set) var quotes: [TokenQuote] = []
    @Published private(set) var scrollSpeed: Double
    @Published private(set) var alertThresholdPercent: Double
    @Published private(set) var jupBaseURL: String
    @Published private(set) var needsPriceAttention: Bool = false

    private let defaultsKey = "jupbar.tokens"
    private let speedKey = "jupbar.scrollSpeed"
    private let alertKey = "jupbar.alertThresholdPercent"
    private let jupBaseKey = "jupbar.jupBaseURL"
    private let defaultJupApiKey = "3309da44-211b-4acb-9d31-c36fb54d9459"
    private var timer: Timer?
    private var jupPrice: JupPriceClient
    private var jupTokens: JupTokenClient
    private var tokenMetaCache: [String: JupTokenMeta] = [:]
    private var priceHistory: [String: [PricePoint]] = [:]
    private var lastAlertedAt: [String: Date] = [:]
    private let alertCooldown: TimeInterval = 600
    private var consecutivePriceFailures: Int = 0

    init() {
        let savedSpeed = UserDefaults.standard.double(forKey: speedKey)
        self.scrollSpeed = savedSpeed > 0 ? savedSpeed : 40
        let savedAlert = UserDefaults.standard.double(forKey: alertKey)
        self.alertThresholdPercent = savedAlert > 0 ? savedAlert : 5
        let savedBase = UserDefaults.standard.string(forKey: jupBaseKey)
        let resolvedBase = Self.sanitizeBaseURL(savedBase) ?? "https://rpc.jup.bar"
        self.jupBaseURL = resolvedBase
        self.jupPrice = JupPriceClient(apiKey: defaultJupApiKey, baseURL: resolvedBase)
        self.jupTokens = JupTokenClient(apiKey: defaultJupApiKey, baseURL: resolvedBase)
        load()
    }

    func updateJupBaseURL(_ value: String) {
        guard let clean = Self.sanitizeBaseURL(value) else { return }
        jupBaseURL = clean
        UserDefaults.standard.set(clean, forKey: jupBaseKey)
        jupPrice = JupPriceClient(apiKey: defaultJupApiKey, baseURL: clean)
        jupTokens = JupTokenClient(apiKey: defaultJupApiKey, baseURL: clean)
        Task { await refresh() }
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
        normalizePinnedOrder()
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
        normalizePinnedOrder()
        persist()
        Task { await refresh() }
    }

    func removeMint(_ mint: String) {
        let clean = mint.trimmingCharacters(in: .whitespacesAndNewlines)
        configs.removeAll { $0.mint == clean }
        normalizePinnedOrder()
        persist()
        Task { await refresh() }
    }

    func moveConfigs(from offsets: IndexSet, to destination: Int) {
        configs.move(fromOffsets: offsets, toOffset: destination)
        normalizePinnedOrder()
        persist()
    }

    func sortConfigsAlphabetically() {
        configs.sort { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }
            return lhs.symbol.lowercased() < rhs.symbol.lowercased()
        }
        normalizePinnedOrder()
        persist()
    }

    func togglePinned(for mint: String) {
        guard let index = configs.firstIndex(where: { $0.mint == mint }) else { return }
        configs[index].pinned.toggle()
        normalizePinnedOrder()
        persist()
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
        let jupPrices = await jupPrice.fetchPrices(mints: mints)
        let hasAnyPrice = jupPrices.values.contains { $0.usdPrice != nil }
        if hasAnyPrice {
            consecutivePriceFailures = 0
            needsPriceAttention = false
        } else {
            consecutivePriceFailures += 1
            if consecutivePriceFailures >= 2 {
                needsPriceAttention = true
            }
        }
        let missingMeta = mints.filter { tokenMetaCache[$0] == nil }
        if !missingMeta.isEmpty {
            let meta = await jupTokens.fetchTokens(mints: missingMeta)
            for (mint, token) in meta {
                tokenMetaCache[mint] = token
            }
        }
        let now = Date()
        let merged = configs.map { config -> TokenQuote in
            let meta = tokenMetaCache[config.mint]
            if let item = jupPrices[config.mint] {
                let price = item.usdPrice
                let change1h = updateHistory(mint: config.mint, price: price, now: now)
                maybePlayAlert(mint: config.mint, change1h: change1h, now: now)
                return TokenQuote(
                    mint: config.mint,
                    symbol: meta?.symbol ?? config.symbol,
                    name: meta?.name,
                    price: price,
                    change1h: change1h,
                    volume1h: nil,
                    volume24h: item.volume24h,
                    marketCap: item.marketCap,
                    liquidity: item.liquidity,
                    ath: item.ath,
                    atl: item.atl,
                    supply: item.supply,
                    holders: item.holders,
                    iconURL: meta?.iconURL
                )
            }
            return TokenQuote(
                mint: config.mint,
                symbol: meta?.symbol ?? config.symbol,
                name: meta?.name,
                price: nil,
                change1h: nil,
                volume1h: nil,
                volume24h: nil,
                marketCap: nil,
                liquidity: nil,
                ath: nil,
                atl: nil,
                supply: nil,
                holders: nil,
                iconURL: meta?.iconURL
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

    private func normalizePinnedOrder() {
        let pinned = configs.filter { $0.pinned }
        let unpinned = configs.filter { !$0.pinned }
        configs = pinned + unpinned
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

    private static func sanitizeBaseURL(_ value: String?) -> String? {
        guard var raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        while raw.hasSuffix("/") { raw.removeLast() }
        guard raw.hasPrefix("http") else { return nil }
        return raw
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
        TokenConfig(mint: "3NZ9JMVBmGAqocybic2c7LQCJScmgsAZ6vQqTDzcqmJh", symbol: "3NZ9", pinned: false),
        TokenConfig(mint: "A4Yevf3KZvCNmst2vTPczCk8UEjqqYp7EPnvxv8EEB8a", symbol: "A4YE", pinned: false),
        TokenConfig(mint: "CMkj12qHC9RjAUs1MED38Bt7gfyP3TbEpa1mcBno3RUY", symbol: "CMKJ", pinned: false),
        TokenConfig(mint: "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263", symbol: "DEZX", pinned: false),
        TokenConfig(mint: "ehipS3kn9GUSnEMgtB9RxCNBVfH5gTNRVxNtqFTBAGS", symbol: "EHIP", pinned: false),
        TokenConfig(mint: "FAFxVxnkzZHMCodkWyoccgUNgVScqMw2mhhQBYDFjFAF", symbol: "FAFX", pinned: false),
        TokenConfig(mint: "JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN", symbol: "JUPY", pinned: false),
        TokenConfig(mint: "PAYmo6moDF3Ro3X6bU2jwe2UdBnBhv8YjLgL1j4DxGu", symbol: "PAYM", pinned: false),
        TokenConfig(mint: "SKRbvo6Gf7GondiT3BbTfuRDPqLWei4j2Qy2NPGZhW3", symbol: "SKRB", pinned: false),
        TokenConfig(mint: "So11111111111111111111111111111111111111112", symbol: "SO11", pinned: false),
        TokenConfig(mint: "METvsvVRapdj9cFLzq4Tr43xK4tAjQfwX76z3n6mWQL", symbol: "METV", pinned: false)
    ]
}

private struct PricePoint {
    let time: Date
    let price: Double
}
