import AppKit
import SwiftUI

struct TickerBarView: View {
    @ObservedObject var tokenStore: TokenStore
    let onToggleFullWidth: () -> Void

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
            Color.black.opacity(0.2)
            HStack(spacing: 8) {
                JupBarLogo()
                    .onTapGesture {
                        openJupBar()
                    }
                    .zIndex(1)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 18)

                let pinned = tokenStore.configs.filter { $0.pinned }
                let pinnedQuotes = tokenStore.quotes.filter { quote in
                    pinned.contains(where: { $0.mint == quote.mint })
                }
                if tokenStore.quotes.isEmpty {
                    Text("Add a Solana mint to start")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    if !pinnedQuotes.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(pinnedQuotes, id: \.mint) { quote in
                                TickerItemView(quote: quote)
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    MarqueeView(speed: tokenStore.scrollSpeed, resetKey: tokenStore.quotes.map(\.mint).joined()) {
                        HStack(spacing: 20) {
                            ForEach(tokenStore.quotes.filter { quote in
                                !pinned.contains(where: { $0.mint == quote.mint })
                            }, id: \.mint) { quote in
                                TickerItemView(quote: quote)
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 34)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onToggleFullWidth()
        }
        .preferredColorScheme(.dark)
    }
}

private struct JupBarLogo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.97, green: 0.69, blue: 0.31), Color(red: 0.98, green: 0.45, blue: 0.38)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 14, height: 14)
                .shadow(color: Color(red: 0.98, green: 0.45, blue: 0.38).opacity(0.4), radius: 6, x: 0, y: 0)
        }
        .frame(width: 36, height: 24)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

private func openJupBar() {
    guard let url = URL(string: "https://jup.bar?ref=bar") else { return }
    NSWorkspace.shared.open(url)
}

struct TickerItemView: View {
    let quote: TokenQuote

    var body: some View {
        HStack(spacing: 8) {
            if let url = quote.iconURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.white.opacity(0.2))
                }
                .frame(width: 14, height: 14)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 14, height: 14)
            }
            Text(quote.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(priceString(quote.price))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(changeValueString(quote.change1h))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(changeColor(quote.change1h))
                .lineLimit(1)
            // Volume removed until reliable data source is wired.
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .onTapGesture {
            openJupiter(for: quote.mint)
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }

    private func priceString(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "$%.6f", value)
    }

    private func changeValueString(_ value: Double?) -> String {
        guard let value else { return "–" }
        let percent = abs(value) <= 1.5 ? value * 100 : value
        return String(format: "%+.2f%%", percent)
    }

    private func volumeString(_ value: Double?) -> String {
        guard let value else { return "Vol --" }
        if value >= 1_000_000 {
            return String(format: "Vol %.2fM", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "Vol %.2fK", value / 1_000)
        }
        return String(format: "Vol %.0f", value)
    }

    private func changeColor(_ value: Double?) -> Color {
        guard let value else { return .secondary }
        return value >= 0 ? .green : .red
    }

    private func openJupiter(for mint: String) {
        guard let url = URL(string: "https://jup.ag/tokens/\(mint)?refId=yfgv2ibxy07v") else { return }
        NSWorkspace.shared.open(url)
    }
}

struct MarqueeView<Content: View>: View {
    let speed: Double
    let resetKey: String
    let content: Content

    @State private var contentWidth: CGFloat = 1
    @State private var containerWidth: CGFloat = 1
    @State private var startTime = Date()
    @State private var pauseStart: Date?
    @State private var totalPaused: TimeInterval = 0

    init(speed: Double, resetKey: String, @ViewBuilder content: () -> Content) {
        self.speed = speed
        self.resetKey = resetKey
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                let elapsed = effectiveElapsed(at: timeline.date)
                let width = max(1, contentWidth)
                let offset = -CGFloat(elapsed * speed).truncatingRemainder(dividingBy: width)
                let repeatCount = max(2, Int(ceil(containerWidth / width)) + 1)
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(0..<repeatCount, id: \.self) { _ in
                            content
                        }
                    }
                    content
                        .hidden()
                        .background(WidthReader())
                }
                .offset(x: offset)
                .onPreferenceChange(WidthPreferenceKey.self) { width in
                    if width > 1 {
                        contentWidth = width
                    }
                }
            }
            .onAppear {
                containerWidth = proxy.size.width
            }
            .onChange(of: proxy.size.width) { newValue in
                containerWidth = newValue
            }
        }
        .clipped()
        .onHover { hovering in
            if hovering {
                pauseStart = Date()
            } else if let pauseStart {
                totalPaused += Date().timeIntervalSince(pauseStart)
                self.pauseStart = nil
            }
        }
        .onChange(of: resetKey) { _ in
            startTime = Date()
            totalPaused = 0
            pauseStart = nil
        }
    }

    private func effectiveElapsed(at date: Date) -> TimeInterval {
        let pausedNow = pauseStart.map { date.timeIntervalSince($0) } ?? 0
        return max(0, date.timeIntervalSince(startTime) - totalPaused - pausedNow)
    }
}

private struct WidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 1
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct WidthReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: WidthPreferenceKey.self, value: proxy.size.width)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
