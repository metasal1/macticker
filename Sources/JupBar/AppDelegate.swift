import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var tickerWindowController: TickerBarWindowController?
    private var manageWindowController: ManageTickersWindowController?
    private var toggleBarItem: NSMenuItem?
    private let tokenStore = TokenStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = AppIcon.makeIcon()
        setupMenuBar()
        tickerWindowController = TickerBarWindowController(tokenStore: tokenStore)
        tickerWindowController?.showWindow(nil)
        manageWindowController = ManageTickersWindowController(tokenStore: tokenStore)
        tokenStore.startPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tokenStore.stopPolling()
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: 24)
        if let button = item.button {
            button.image = AppIcon.makeMenuBarIcon()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.image?.size = NSSize(width: 18, height: 18)
            button.toolTip = "Jup Bar"
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Manage Tickers…", action: #selector(showManage), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "Toggle Full Width", action: #selector(toggleFullWidth), keyEquivalent: "f"))
        let toggleItem = NSMenuItem(title: "Hide Bar", action: #selector(toggleBar), keyEquivalent: "h")
        menu.addItem(toggleItem)
        toggleBarItem = toggleItem
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Jup Bar", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        let attribution = NSMenuItem(title: "Metasal — metasal.xyz", action: nil, keyEquivalent: "")
        attribution.isEnabled = false
        menu.addItem(attribution)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func showManage() {
        manageWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleFullWidth() {
        tickerWindowController?.toggleFullWidthFromMenu()
    }

    @objc private func toggleBar() {
        guard let controller = tickerWindowController else { return }
        let isVisible = controller.toggleVisibility()
        toggleBarItem?.title = isVisible ? "Hide Bar" : "Show Bar"
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let info = VersionInfo.current
        let credits = AboutCredits.make()
        NSApp.applicationIconImage = AppIcon.makeIcon()
        NSApp.orderFrontStandardAboutPanel(options: [
            NSApplication.AboutPanelOptionKey.applicationName: "Jup Bar",
            NSApplication.AboutPanelOptionKey.version: "Version \(info.shortVersion)",
            NSApplication.AboutPanelOptionKey.applicationVersion: "Build \(info.build)",
            NSApplication.AboutPanelOptionKey.credits: credits
        ])
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

private enum AppIcon {
    static func makeIcon() -> NSImage {
        let size = NSSize(width: 256, height: 256)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        NSColor.clear.setFill()
        rect.fill()
        let circleRect = rect.insetBy(dx: 32, dy: 32)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.97, green: 0.69, blue: 0.31, alpha: 1.0),
            NSColor(calibratedRed: 0.98, green: 0.45, blue: 0.38, alpha: 1.0)
        ])
        gradient?.draw(in: NSBezierPath(ovalIn: circleRect), angle: 45)
        image.unlockFocus()
        return image
    }

    static func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        NSColor.clear.setFill()
        rect.fill()
        let circleRect = rect.insetBy(dx: 2.5, dy: 2.5)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.97, green: 0.69, blue: 0.31, alpha: 1.0),
            NSColor(calibratedRed: 0.98, green: 0.45, blue: 0.38, alpha: 1.0)
        ])
        gradient?.draw(in: NSBezierPath(ovalIn: circleRect), angle: 45)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

private struct VersionInfo {
    let shortVersion: String
    let build: String

    static var current: VersionInfo {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return VersionInfo(shortVersion: short, build: build)
    }
}

private enum AboutCredits {
    static func make() -> NSAttributedString {
        let text = "jup.bar\nMade by metasal.xyz"
        let attr = NSMutableAttributedString(string: text)
        let full = NSRange(location: 0, length: attr.length)
        attr.addAttribute(.font, value: NSFont.systemFont(ofSize: 11), range: full)
        let jupRange = (text as NSString).range(of: "jup.bar")
        let metaRange = (text as NSString).range(of: "metasal.xyz")
        if let url = URL(string: "https://jup.bar") {
            attr.addAttribute(.link, value: url, range: jupRange)
        }
        if let url = URL(string: "https://metasal.xyz") {
            attr.addAttribute(.link, value: url, range: metaRange)
        }
        return attr
    }
}
