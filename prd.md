# jup.bar PRD

## Summary
jup.bar is a lightweight macOS floating ticker bar that scrolls prices for favorite Solana tokens. Users can add/remove tickers and click a ticker to open Jupiter (Jup) for that token. Built to feel fast, native, and good-looking on macOS, with a menu bar presence for quick access.

## Goals
- Provide a minimal, always-available ticker bar that stays on top.
- Show real-time price and 24h change for user-selected Solana tokens.
- Enable quick trading via one-click open in Jupiter.
- Keep the UI polished and native-feeling on macOS.

## Non-Goals
- Full portfolio tracking or PnL.
- Order placement inside the app.
- Cross-chain token support.

## Target Users
- Solana traders who want a quick glance at prices without switching contexts.

## Core User Stories
1. As a user, I can view a scrolling list of my favorite Solana tickers and their prices.
2. As a user, I can add a new ticker by symbol or mint address.
3. As a user, I can remove a ticker from the list.
4. As a user, I can click a ticker to open Jupiter for that token.

## Functional Requirements
- Floating bar window
  - Always-on-top, frameless, and draggable.
  - Docked by default at top of screen; can be moved.
  - Spans full screen width by default.
  - Smooth, GPU-accelerated scrolling.
- Ticker display
  - Shows token icon (if available), symbol, last price, and 24h % change.
  - Scrolls horizontally at a steady, configurable speed.
  - Uses color cues for % change (green/red).
  - Hover over the bar pauses scrolling.
- Data
  - Price and token metadata are pulled from Helius RPC.
  - Refresh interval is configurable (default 30s).
  - Show 1h % change and 1h volume.
  - User can supply their own RPC URL.
- Manage tickers
  - Add by mint address (paste).
  - Remove from a list UI or via context menu.
  - Persist the list locally.
- Jupiter integration
  - Clicking a ticker opens Jupiter in the browser with the token preselected.
  - URL format: `https://jup.ag/tokens/<MINT>?ref=yfgv2ibxy07v`.
- Menu bar
  - Menu bar icon with quick access to add, delete, and quit.

## UX Requirements
- Minimal chrome; no heavy controls in the bar.
- Hover or click reveals quick actions (open, remove).
- Add/remove UI is accessible via a small settings button or menu bar icon.
- Visual style feels native to macOS with crisp typography and subtle separators.
- Support light/dark mode automatically.

## Accessibility
- Sufficient color contrast for text and price changes.
- Option to increase font size.

## Performance
- Low CPU usage (<2% idle).
- Startup under 1s on modern Macs.
- Maintain 60fps scrolling on typical hardware.

## Edge Cases
- Token symbol collisions (multiple mints): prompt to choose mint.
- Invalid or delisted tokens: show error state and allow removal.
- Network failures: show stale indicator and retry.

## Data Source
- Use Helius RPC for token price + metadata.
- Support a user-provided RPC URL.
- Cache token metadata and icons locally.

## Open Questions
- Should the bar support multiple rows or a single row only?
- Default starter tickers (e.g., SOL, JUP)?

## Defaults
- Starter tickers: `SOL`, `JUP`, `MET`, `BONK`, `PAYAI`, `RADR`.
- Auto-start on login.
- Remember last bar position.

## Tech Stack
- SwiftUI app with AppKit interop for always-on-top, frameless window.
- Menu bar item + Dock app (both visible).

## Success Metrics
- Daily active usage.
- Median time spent visible per day.
- % of users adding/removing tickers within first session.
