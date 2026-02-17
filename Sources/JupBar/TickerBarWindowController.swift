import AppKit
import SwiftUI

// MARK: - Private CGS API for screen space reservation
// CGSSetWorkspaceInsets adjusts NSScreen.visibleFrame for all apps — like the Dock does.
// Parameters: (connection, left, bottom, right, top) in screen points.
private typealias CGSConnectionID = UInt32

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> CGSConnectionID

@discardableResult
@_silgen_name("CGSSetWorkspaceInsets")
private func CGSSetWorkspaceInsets(
    _ cid: CGSConnectionID,
    _ left: CGFloat, _ bottom: CGFloat,
    _ right: CGFloat, _ top: CGFloat
) -> CGError

// MARK: - Pinned Edge

private enum PinnedEdge: String {
    case none   = ""
    case top    = "top"
    case bottom = "bottom"
}

// MARK: - Window Controller

@MainActor
final class TickerBarWindowController: NSWindowController {
    private let tokenStore: TokenStore
    private let usageStore: UsageStatsStore
    private static let positionKeyX  = "jupbar.windowOriginX"
    private static let positionKeyY  = "jupbar.windowOriginY"
    private static let pinnedEdgeKey = "jupbar.pinnedEdge"
    private var lastNonFullFrame: NSRect?
    private var isFullWidth = true
    private var keyMonitor: Any?
    private var isHidden = false

    // Snap-to-edge state
    private let snapThreshold: CGFloat = 24
    private var snapTimer: Timer?
    private var pinnedEdge: PinnedEdge = .none

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

        // Restore pinned state from last session
        let savedEdge = PinnedEdge(rawValue: UserDefaults.standard.string(forKey: Self.pinnedEdgeKey) ?? "") ?? .none
        if savedEdge != .none {
            pinnedEdge = savedEdge
            applyPinnedFrame(for: savedEdge, animated: false)
            applyScreenInsets(for: savedEdge)
        }

        // Clear insets when app quits so the workspace isn't left with a reserved gap
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearScreenInsetsOnQuit),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        snapTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Existing helpers

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
            // Toggling to non-full-width unpins
            if pinnedEdge != .none {
                clearPinnedEdge()
            }
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

    // MARK: - Snap to Edge

    /// Called from windowDidMove with a short debounce so snapping happens on drop, not mid-drag.
    private func scheduleSnapCheck() {
        snapTimer?.invalidate()
        snapTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkEdgeSnap()
            }
        }
    }

    private func checkEdgeSnap() {
        guard let window = window, let screen = activeScreen(for: window) else { return }
        let barHeight = window.frame.height

        // Top snap target: just below the menu bar (screen.visibleFrame.maxY)
        let visibleTop = screen.visibleFrame.maxY - barHeight
        // Bottom snap target: bottom of visible frame (above the Dock)
        let visibleBottom = screen.visibleFrame.minY

        let currentY = window.frame.origin.y

        if abs(currentY - visibleTop) <= snapThreshold {
            snapToEdge(.top, window: window, screen: screen)
        } else if abs(currentY - visibleBottom) <= snapThreshold {
            snapToEdge(.bottom, window: window, screen: screen)
        } else if pinnedEdge != .none {
            // Dragged away from edge — unpin
            clearPinnedEdge()
        }
    }

    private func snapToEdge(_ edge: PinnedEdge, window: NSWindow, screen: NSScreen) {
        // Expand to full width and snap to edge
        lastNonFullFrame = nil
        isFullWidth = true
        applyPinnedFrame(for: edge, animated: true)
        pinnedEdge = edge
        UserDefaults.standard.set(edge.rawValue, forKey: Self.pinnedEdgeKey)
        applyScreenInsets(for: edge)
        savePosition(window)
    }

    private func clearPinnedEdge() {
        pinnedEdge = .none
        UserDefaults.standard.set("", forKey: Self.pinnedEdgeKey)
        applyScreenInsets(for: .none)
    }

    /// Moves the window to the snapped position for a given edge.
    private func applyPinnedFrame(for edge: PinnedEdge, animated: Bool) {
        guard let window = window, let screen = activeScreen(for: window) else { return }
        let screenFrame = screen.frame
        let barHeight = window.frame.height

        let targetY: CGFloat
        switch edge {
        case .top:
            targetY = screen.visibleFrame.maxY - barHeight
        case .bottom:
            targetY = screen.visibleFrame.minY
        case .none:
            return
        }

        let newFrame = NSRect(
            x: screenFrame.minX,
            y: targetY,
            width: screenFrame.width,
            height: barHeight
        )
        window.setFrame(newFrame, display: true, animate: animated)
    }

    // MARK: - Screen Space Reservation (CGS)

    /// Reserves screen space so app windows won't maximize/tile into the bar area.
    /// Uses the private CGSSetWorkspaceInsets API — the same mechanism as the Dock.
    private func applyScreenInsets(for edge: PinnedEdge) {
        guard let window = window else { return }
        let barHeight = window.frame.height
        let cid = CGSMainConnectionID()

        switch edge {
        case .top:
            // Reserve barHeight pts from the top (below the menu bar)
            CGSSetWorkspaceInsets(cid, 0, 0, 0, barHeight)
        case .bottom:
            // Reserve barHeight pts from the bottom (above the Dock)
            CGSSetWorkspaceInsets(cid, 0, barHeight, 0, 0)
        case .none:
            CGSSetWorkspaceInsets(cid, 0, 0, 0, 0)
        }
    }

    @objc private func clearScreenInsetsOnQuit() {
        let cid = CGSMainConnectionID()
        CGSSetWorkspaceInsets(cid, 0, 0, 0, 0)
    }
}

// MARK: - NSWindowDelegate

extension TickerBarWindowController: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        savePosition(window)
        // If currently pinned and the user drags, trigger a snap-check on drop
        scheduleSnapCheck()
    }

    func windowWillClose(_ notification: Notification) {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        snapTimer?.invalidate()
        clearScreenInsetsOnQuit()
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

// MARK: - Private helpers

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

    func savePosition(_ window: NSWindow) {
        let origin = window.frame.origin
        UserDefaults.standard.set(origin.x, forKey: Self.positionKeyX)
        UserDefaults.standard.set(origin.y, forKey: Self.positionKeyY)
    }
}
