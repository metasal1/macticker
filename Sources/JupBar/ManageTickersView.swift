import SwiftUI
import AppKit

struct ManageTickersView: View {
    @ObservedObject var tokenStore: TokenStore
    let onClose: () -> Void

    @State private var newMint: String = ""
    @State private var selectedMint: String?
    @State private var rpcURL: String = ""
    @State private var speedValue: Double = 40
    @State private var alertThreshold: Double = 5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                    HStack(spacing: 8) {
                        Button(action: {
                            tokenStore.togglePinned(for: config.mint)
                        }) {
                            Image(systemName: config.pinned ? "pin.fill" : "pin")
                                .foregroundStyle(config.pinned ? .primary : .secondary)
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
                            tokenStore.removeMint(config.mint)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
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

                Text("RPC")
                    .font(.system(size: 14, weight: .semibold))
                HStack {
                    TextField("Helius RPC URL", text: $rpcURL)
                        .textFieldStyle(.roundedBorder)
                }
                Text("Default: https://viviyan-bkj12u-fast-mainnet.helius-rpc.com")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Divider()

                HStack {
                    Text("Metasal — metasal.xyz")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                Button("Save") {
                    let url = rpcURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !url.isEmpty {
                        tokenStore.updateRPCURL(url)
                    }
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
            rpcURL = tokenStore.rpcURL
            speedValue = tokenStore.scrollSpeed
            alertThreshold = tokenStore.alertThresholdPercent
        }
        .preferredColorScheme(.dark)
    }

    private func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["csv"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url,
           let content = try? String(contentsOf: url, encoding: .utf8) {
            tokenStore.importCSV(content)
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["csv"]
        panel.nameFieldStringValue = "jupbar-tokens.csv"
        if panel.runModal() == .OK, let url = panel.url {
            let content = tokenStore.exportCSV()
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
