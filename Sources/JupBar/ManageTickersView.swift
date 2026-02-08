import SwiftUI
import AppKit

struct ManageTickersView: View {
    @ObservedObject var tokenStore: TokenStore
    @ObservedObject var usageStore: UsageStatsStore
    let onClose: () -> Void

    @State private var newMint: String = ""
    @State private var selectedMint: String?
    @State private var speedValue: Double = 40
    @State private var alertThreshold: Double = 5
    @State private var jupApiKey: String = ""
    @State private var jupBaseURL: String = ""
    @State private var expandedMint: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Live Viewers")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(usageStore.activeUsers.map { "\($0)" } ?? "--")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(usageStore.isConnected ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(usageStore.isConnected ? Color.green.opacity(0.15) : Color.white.opacity(0.08))
                    )
                Spacer()
            }
            Text("Quick Add")
                .font(.system(size: 14, weight: .semibold))
            HStack {
                TextField("Paste mint address(es)", text: $newMint)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let mint = newMint.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !mint.isEmpty else { return }
                    tokenStore.addPastedMints(mint)
                    newMint = ""
                }
            }

            Text("Current Tickers")
                .font(.system(size: 14, weight: .semibold))
            HStack {
                Text("Drag to reorder")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Sort A–Z") {
                    tokenStore.sortConfigsAlphabetically()
                }
                .font(.system(size: 11, weight: .medium))
            }

            ZStack {
                List(selection: $selectedMint) {
                    ForEach(tokenStore.configs) { config in
                        let quote = tokenStore.quotes.first(where: { $0.mint == config.mint })
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Button(action: {
                                tokenStore.togglePinned(for: config.mint)
                            }) {
                                Image(systemName: config.pinned ? "star.fill" : "star")
                                    .foregroundStyle(config.pinned ? .yellow : .secondary)
                            }
                            .buttonStyle(.plain)
                            if let url = quote?.iconURL {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(Color.white.opacity(0.2))
                                }
                                .frame(width: 18, height: 18)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 18, height: 18)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(quote?.symbol ?? config.symbol)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(quote?.name ?? config.mint)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    expandedMint = (expandedMint == config.mint) ? nil : config.mint
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("Details")
                                        .font(.system(size: 10, weight: .semibold))
                                    Image(systemName: expandedMint == config.mint ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.16))
                                )
                                .foregroundStyle(.primary)
                            }
                            .buttonStyle(.plain)
                            Button(action: {
                                tokenStore.removeMint(config.mint)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        if expandedMint == config.mint {
                            VStack(alignment: .leading, spacing: 6) {
                                detailRow("24h Volume", formatCurrency(quote?.volume24h))
                                detailRow("Market Cap", formatCurrency(quote?.marketCap))
                                detailRow("Liquidity", formatCurrency(quote?.liquidity))
                                detailRow("All-Time High", formatCurrency(quote?.ath))
                                detailRow("All-Time Low", formatCurrency(quote?.atl))
                                detailRow("Supply", formatNumber(quote?.supply))
                                detailRow("Holders", formatInt(quote?.holders))
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 26)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(config.pinned ? Color.white.opacity(0.06) : Color.clear)
                    .tag(config.mint)
                    }
                    .onMove { indices, newOffset in
                        tokenStore.moveConfigs(from: indices, to: newOffset)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: 180)

                if tokenStore.configs.isEmpty {
                    Text("No tickers yet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

                HStack {
                    Button("Delete Selected") {
                        guard let selectedMint else { return }
                        tokenStore.removeMint(selectedMint)
                    }
                    .disabled(selectedMint == nil)
                    Spacer()
                }

                Divider()

                Text("Scroll Speed")
                    .font(.system(size: 14, weight: .semibold))
                HStack {
                    Slider(value: $speedValue, in: 10...160, step: 1)
                    Text("\(Int(speedValue))")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 36, alignment: .trailing)
                }

                Text("Price Move Alert")
                    .font(.system(size: 14, weight: .semibold))
                Text("Price change is based on 1h move")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                HStack {
                    Slider(value: $alertThreshold, in: 0.5...25, step: 0.5)
                    Text(String(format: "%.1f%%", alertThreshold))
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 56, alignment: .trailing)
                }

                Divider()

                Text("Import / Export")
                    .font(.system(size: 14, weight: .semibold))
                HStack {
                    Button("Import CSV") {
                        importCSV()
                    }
                    Button("Export CSV") {
                        exportCSV()
                    }
                    Spacer()
                }

                Divider()

                Text("Sound")
                    .font(.system(size: 14, weight: .semibold))
                HStack {
                    Button("Test Alert") {
                        NSSound(named: "Ping")?.play()
                    }
                    Spacer()
                }

                Divider()

            HStack(spacing: 8) {
                Text("Jupiter API Key")
                    .font(.system(size: 14, weight: .semibold))
                Link("Get one", destination: URL(string: "https://portal.jup.ag/login")!)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            HStack {
                TextField("Jup API key", text: $jupApiKey)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    let key = jupApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !key.isEmpty else { return }
                    tokenStore.updateJupApiKey(key)
                }
            }
            if tokenStore.needsApiKey {
                Text("No prices found. Add a valid Jupiter API key to load prices.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            Text("Jupiter RPC / Base URL")
                .font(.system(size: 14, weight: .semibold))
            HStack {
                TextField("https://rpc.jup.bar", text: $jupBaseURL)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    let value = jupBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty else { return }
                    tokenStore.updateJupBaseURL(value)
                }
            }


                Divider()

                HStack {
                    Text("Metasal — metasal.xyz")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                Button("Save") {
                    tokenStore.updateScrollSpeed(speedValue)
                    tokenStore.updateAlertThreshold(alertThreshold)
                    onClose()
                }
                Button("Close") {
                    onClose()
                }
                }
            }
            .padding(16)
        }
        .onAppear {
            speedValue = tokenStore.scrollSpeed
            alertThreshold = tokenStore.alertThresholdPercent
            jupApiKey = tokenStore.jupApiKey
            jupBaseURL = tokenStore.jupBaseURL
        }
        .preferredColorScheme(.dark)
    }

    private func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url,
           let content = try? String(contentsOf: url, encoding: .utf8) {
            tokenStore.importCSV(content)
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "jupbar-tokens.csv"
        if panel.runModal() == .OK, let url = panel.url {
            let content = tokenStore.exportCSV()
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
    }

    private func formatCurrency(_ value: Double?) -> String {
        guard let value else { return "—" }
        if abs(value) >= 1_000_000_000 {
            return String(format: "$%.2fB", value / 1_000_000_000)
        }
        if abs(value) >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        }
        if abs(value) >= 1_000 {
            return String(format: "$%.2fK", value / 1_000)
        }
        return String(format: "$%.2f", value)
    }

    private func formatNumber(_ value: Double?) -> String {
        guard let value else { return "—" }
        if abs(value) >= 1_000_000_000 {
            return String(format: "%.2fB", value / 1_000_000_000)
        }
        if abs(value) >= 1_000_000 {
            return String(format: "%.2fM", value / 1_000_000)
        }
        if abs(value) >= 1_000 {
            return String(format: "%.2fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }

    private func formatInt(_ value: Int?) -> String {
        guard let value else { return "—" }
        if value >= 1_000_000_000 {
            return String(format: "%.2fB", Double(value) / 1_000_000_000)
        }
        if value >= 1_000_000 {
            return String(format: "%.2fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.2fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}
