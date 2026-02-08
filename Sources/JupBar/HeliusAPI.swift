import Foundation

actor HeliusAPI {
    private let session: URLSession
    private let rpcURL: URL

    init(rpcURL: String, session: URLSession = .shared) {
        self.session = session
        self.rpcURL = URL(string: rpcURL) ?? URL(string: "https://api.mainnet-beta.solana.com")!
    }

    func fetchQuotes(mints: [String]) async -> [String: TokenQuote] {
        guard !mints.isEmpty else { return [:] }
        let assets = await fetchAssets(mints: mints)
        var result: [String: TokenQuote] = [:]
        for asset in assets {
            let symbol = asset.tokenInfo?.symbol ?? asset.content?.metadata?.symbol ?? shortSymbol(for: asset.id)
            let name = asset.content?.metadata?.name
            let price = asset.tokenInfo?.priceInfo?.pricePerToken
            let iconURL = asset.content?.links?.imageURL
            result[asset.id] = TokenQuote(
                mint: asset.id,
                symbol: symbol,
                name: name,
                price: price,
                change1h: nil,
                volume1h: nil,
                volume24h: nil,
                marketCap: nil,
                liquidity: nil,
                ath: nil,
                atl: nil,
                supply: nil,
                holders: nil,
                iconURL: iconURL
            )
        }
        return result
    }

    private func fetchAssets(mints: [String]) async -> [HeliusAsset] {
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = HeliusRequest(
            jsonrpc: "2.0",
            id: "mac-ticker",
            method: "getAssetBatch",
            params: HeliusAssetBatchParams(ids: mints)
        )
        guard let data = try? JSONEncoder().encode(body) else { return [] }
        request.httpBody = data
        do {
            let (responseData, _) = try await session.data(for: request)
            let decoded = try JSONDecoder().decode(HeliusAssetBatchResponse.self, from: responseData)
            return decoded.result
        } catch {
            return []
        }
    }

    private func shortSymbol(for mint: String) -> String {
        let prefix = mint.prefix(4)
        return String(prefix).uppercased()
    }
}

private struct HeliusRequest: Encodable {
    let jsonrpc: String
    let id: String
    let method: String
    let params: HeliusAssetBatchParams
}

private struct HeliusAssetBatchParams: Encodable {
    let ids: [String]
}

private struct HeliusAssetBatchResponse: Decodable {
    let result: [HeliusAsset]
}

private struct HeliusAsset: Decodable {
    let id: String
    let content: HeliusContent?
    let tokenInfo: HeliusTokenInfo?

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case tokenInfo = "token_info"
    }
}

private struct HeliusContent: Decodable {
    let metadata: HeliusMetadata?
    let links: HeliusLinks?
}

private struct HeliusMetadata: Decodable {
    let symbol: String?
    let name: String?
}

private struct HeliusLinks: Decodable {
    let image: String?

    var imageURL: URL? {
        guard let image, let url = URL(string: image) else { return nil }
        return url
    }
}

private struct HeliusTokenInfo: Decodable {
    let symbol: String?
    let priceInfo: HeliusPriceInfo?

    enum CodingKeys: String, CodingKey {
        case symbol
        case priceInfo = "price_info"
    }
}

private struct HeliusPriceInfo: Decodable {
    let pricePerToken: Double?

    enum CodingKeys: String, CodingKey {
        case pricePerToken = "price_per_token"
    }
}
