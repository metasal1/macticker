import Foundation

struct TokenConfig: Codable, Hashable, Identifiable {
    var id: String { mint }
    let mint: String
    var symbol: String
    var pinned: Bool
}

struct TokenQuote: Hashable {
    let mint: String
    let symbol: String
    let name: String?
    let price: Double?
    let change1h: Double?
    let volume1h: Double?
    let iconURL: URL?
}
