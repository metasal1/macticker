import AppKit
import SwiftUI

@MainActor
final class TickerBarWindowController: NSWindowController {
    private let tokenStore: TokenStore
    private let usageStore: UsageStatsStore
    private static let positionKeyX = "jupbar.windowOriginX"
    private static let positionKeyY = "jupbar.windowOriginY"
    private var lastNonFullFrame: NSRect?
    private var isFullWidth = true
    private var keyMonitor: Any?
    private var isHidden = false

    init(tokenStore: TokenStore, usageStore: UsageStatsStore) {
        self.tokenStore = tokenStore
        self.usageStore = usageStore
        let screenFrame = NSScreen.main?.frame ?? .zero
        let height: CGFloat = 34
        let defaultOrigin = NSPoint(x: 0, y: screenFrame.height - height)
        let savedOrigin = Self.loadOrigin(defaultOrigin: defaultOrigin)
        let window = NSWindow(
            contentRect: NSRect(x: savedOrigin.x, y: savedOrigin.y, width: screenFrame.width, height: height),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = true
        window.acceptsMouseMovedEvents = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 320, height: height)
        window.maxSize = NSSize(width: screenFrame.width, height: height)
        super.init(window: window)
        isFullWidth = abs(window.frame.width - screenFrame.width) < 2
        let contentView = TickerBarView(tokenStore: tokenStore, usageStore: usageStore, onToggleFullWidth: { [weak self] in
            self?.toggleFullWidth()
        })
        let hostingView = NSHostingView(rootView: contentView)
        if let menu = (NSApp.delegate as? AppDelegate)?.makeContextMenu() {
            hostingView.menu = menu
            let press = NSPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
            press.minimumPressDuration = 0.4
            hostingView.addGestureRecognizer(press)
        }
        window.contentView = hostingView
        window.delegate = self
        installKeyMonitor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    private static func loadOrigin(defaultOrigin: NSPoint) -> NSPoint {
        let defaults = UserDefaults.standard
        let x = defaults.double(forKey: Self.positionKeyX)
        let y = defaults.double(forKey: Self.positionKeyY)
        if x == 0 && y == 0 {
            return defaultOrigin
        }
        return NSPoint(x: x, y: y)
    }

    func toggleFullWidthFromMenu() {
        toggleFullWidth()
    }

    func toggleVisibility() -> Bool {
        guard let window = window else { return false }
        if isHidden {
            window.orderFrontRegardless()
            isHidden = false
        } else {
            window.orderOut(nil)
            isHidden = true
        }
        return !isHidden
    }

    private func toggleFullWidth() {
        guard let window = window, let screen = activeScreen(for: window) else { return }
        let screenFrame = screen.frame
        if isFullWidth {
            let targetFrame: NSRect
            if let last = lastNonFullFrame {
                let centeredX = screenFrame.minX + (screenFrame.width - last.width) / 2
                let clampedY = clampY(last.origin.y, height: last.height, in: screenFrame)
                targetFrame = NSRect(x: centeredX, y: clampedY, width: last.width, height: last.height)
            } else {
                let width = max(360, screenFrame.width * 0.6)
                let x = screenFrame.minX + (screenFrame.width - width) / 2
                let clampedY = clampY(window.frame.origin.y, height: window.frame.height, in: screenFrame)
                targetFrame = NSRect(x: x, y: clampedY, width: width, height: window.frame.height)
            }
            window.setFrame(targetFrame, display: true, animate: true)
            isFullWidth = false
        } else {
            lastNonFullFrame = window.frame
            let clampedY = clampY(window.frame.origin.y, height: window.frame.height, in: screenFrame)
            let newFrame = NSRect(x: screenFrame.minX, y: clampedY, width: screenFrame.width, height: window.frame.height)
            window.setFrame(newFrame, display: true, animate: true)
            isFullWidth = true
        }
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 123 { // left arrow
                self.nudgeWidth(delta: -40)
                return nil
            }
            if event.keyCode == 124 { // right arrow
                self.nudgeWidth(delta: 40)
                return nil
            }
            return event
        }
    }

    private func nudgeWidth(delta: CGFloat) {
        guard let window = window, let screen = activeScreen(for: window) else { return }
        let screenFrame = screen.frame
        let screenWidth = screenFrame.width
        let minWidth = window.minSize.width
        let maxWidth = screenWidth
        var frame = window.frame
        let newWidth = max(minWidth, min(maxWidth, frame.width + delta))
        let centeredX = screenFrame.minX + (screenWidth - newWidth) / 2
        frame.origin.x = centeredX
        frame.size.width = newWidth
        frame.origin.y = clampY(frame.origin.y, height: frame.height, in: screenFrame)
        window.setFrame(frame, display: true, animate: true)
        updateFullWidthState(for: window)
    }
}

extension TickerBarWindowController: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let origin = window.frame.origin
        let defaults = UserDefaults.standard
        defaults.set(origin.x, forKey: Self.positionKeyX)
        defaults.set(origin.y, forKey: Self.positionKeyY)
    }

    func windowWillClose(_ notification: Notification) {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        updateFullWidthState(for: window)
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        updateFullWidthState(for: window)
    }

    private func updateFullWidthState(for window: NSWindow) {
        guard let screen = activeScreen(for: window) else { return }
        let screenFrame = screen.frame
        let full = abs(window.frame.width - screenFrame.width) < 2
        isFullWidth = full
        if !full {
            lastNonFullFrame = window.frame
        }
    }

    @objc private func handlePress(_ sender: NSPressGestureRecognizer) {
        guard sender.state == .began || sender.state == .ended else { return }
        guard let view = sender.view, let menu = view.menu else { return }
        let location = sender.location(in: view)
        menu.popUp(positioning: nil, at: location, in: view)
    }
}

private extension TickerBarWindowController {
    func activeScreen(for window: NSWindow) -> NSScreen? {
        if let screen = window.screen { return screen }
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }

    func clampY(_ y: CGFloat, height: CGFloat, in frame: NSRect) -> CGFloat {
        let minY = frame.minY
        let maxY = frame.maxY - height
        return min(max(y, minY), maxY)
    }
}
