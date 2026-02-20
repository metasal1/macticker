import AppKit
import SwiftUI

struct TickerBarView: View {
    @ObservedObject var tokenStore: TokenStore
    @ObservedObject var usageStore: UsageStatsStore
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

                LiveUsersBadge(count: usageStore.activeUsers, isConnected: usageStore.isConnected)

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
                        DividerRow(items: pinnedQuotes, id: { $0.mint }, itemSpacing: 4) { quote in
                            TickerItemView(
                                quote: quote,
                                isPinned: true,
                                onOpen: { openJupiter(for: quote.mint) },
                                onPin: { tokenStore.togglePinned(for: quote.mint) },
                                onUnpin: { tokenStore.togglePinned(for: quote.mint) }
                            )
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    MarqueeView(speed: tokenStore.scrollSpeed, resetKey: tokenStore.quotes.map(\.mint).joined()) {
                        DividerRow(items: tokenStore.quotes.filter { quote in
                            !pinned.contains(where: { $0.mint == quote.mint })
                        }, id: { $0.mint }, itemSpacing: 4) { quote in
                            TickerItemView(
                                quote: quote,
                                isPinned: false,
                                onOpen: { openJupiter(for: quote.mint) },
                                onPin: { tokenStore.togglePinned(for: quote.mint) },
                                onUnpin: { tokenStore.togglePinned(for: quote.mint) }
                            )
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

private struct DividerRow<Item, Content: View>: View {
    let items: [Item]
    let id: (Item) -> String
    let itemSpacing: CGFloat
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        HStack(spacing: itemSpacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                content(item)
                if index != items.count - 1 {
                    Text("|")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct LiveUsersBadge: View {
    let count: Int?
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            Text(count.map { "\($0) live" } ?? "--")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
        )
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .help("Live viewers")
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

private func openJupiter(for mint: String) {
    guard let url = URL(string: "https://jup.ag/tokens/\(mint)?refId=yfgv2ibxy07v") else { return }
    NSWorkspace.shared.open(url)
}

struct TickerItemView: View {
    let quote: TokenQuote
    let isPinned: Bool
    let onOpen: () -> Void
    let onPin: () -> Void
    let onUnpin: () -> Void

    @State private var isHovering = false
    @State private var isHoveringStar = false

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
            priceText(quote.price)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(changeValueString(quote.change1h))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(changeColor(quote.change1h))
                .lineLimit(1)
            // Volume removed until reliable data source is wired.
            Button(action: {
                isPinned ? onUnpin() : onPin()
            }) {
                Image(systemName: isPinned ? "star.fill" : "star")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isPinned ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || isPinned ? 1 : 0)
            .animation(.easeInOut(duration: 0.12), value: isHovering)
            .onHover { hovering in
                isHoveringStar = hovering
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isPinned ? Color.white.opacity(0.12) : Color.clear)
        )
        .frame(maxHeight: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isHoveringStar {
                onOpen()
            }
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }

    private func priceText(_ value: Double?) -> Text {
        guard let value else { return Text("--") }

        // Use subscript notation when decimals have multiple leading zeros.
        // Example: 0.00000611 (five zeros) -> "$0.0₄611"
        if shouldUseSubscript(value) {
            return subscriptPriceText(value)
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.usesGroupingSeparator = true
        if value >= 1 {
            formatter.maximumFractionDigits = 2
        } else if value >= 0.1 {
            formatter.maximumFractionDigits = 6
        } else {
            formatter.maximumFractionDigits = 9
        }
        formatter.minimumFractionDigits = 0
        let string = formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.9f", value)
        return Text(string)
    }

    private func shouldUseSubscript(_ value: Double) -> Bool {
        guard value > 0, value < 1 else { return false }
        let fixed = String(format: "%.12f", value)
        guard let dot = fixed.firstIndex(of: ".") else { return false }
        let decimals = fixed[fixed.index(after: dot)...]
        let zeroCount = decimals.prefix { $0 == "0" }.count
        return zeroCount >= 2
    }

    private func subscriptPriceText(_ value: Double) -> Text {
        // Fixed-point string for stable digit extraction (avoid scientific notation).
        var fixed = String(format: "%.12f", value)
        while fixed.contains(".") && fixed.last == "0" { fixed.removeLast() }
        if fixed.last == "." { fixed.append("0") }

        guard let dot = fixed.firstIndex(of: ".") else {
            return Text("$\(fixed)")
        }
        let decimals = fixed[fixed.index(after: dot)...]
        let zeroCount = decimals.prefix { $0 == "0" }.count
        let significantStart = decimals.index(decimals.startIndex, offsetBy: zeroCount, limitedBy: decimals.endIndex) ?? decimals.endIndex
        let significant = String(decimals[significantStart...].prefix(5))

        // We always show "$0.0" then a subscript indicating extra zeros beyond that first 0.
        let extraZeros = max(0, zeroCount - 1)

        var attr = AttributedString("$0.0")
        if extraZeros > 0 {
            var sub = AttributedString("\(extraZeros)")
            sub.font = .system(size: 9, weight: .semibold)
            sub.baselineOffset = -3
            attr.append(sub)
        }
        attr.append(AttributedString(significant.isEmpty ? "0" : significant))
        return Text(attr)
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
