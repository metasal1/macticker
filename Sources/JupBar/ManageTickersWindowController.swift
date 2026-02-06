import AppKit
import SwiftUI

final class ManageTickersWindowController: NSWindowController {
    init(tokenStore: TokenStore) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 760),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Manage jup.bar"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 560, height: 700)
        let contentView = ManageTickersView(tokenStore: tokenStore, onClose: { [weak window] in
            window?.performClose(nil)
        })
        window.contentView = NSHostingView(rootView: contentView)
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
