import Foundation

struct JupPriceClient {
    let apiKey: String
    let baseURL: String

    init(apiKey: String, baseURL: String = "https://api.jup.ag") {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    func fetchPrices(mints: [String]) async -> [String: JupPriceItem] {
        guard !mints.isEmpty else { return [:] }
        var result: [String: JupPriceItem] = [:]
        let chunks = stride(from: 0, to: mints.count, by: 50).map {
            Array(mints[$0..<min($0 + 50, mints.count)])
        }
        for chunk in chunks {
            if let decoded = await fetchChunk(mints: chunk, base: baseURL) {
                for (mint, item) in decoded {
                    result[mint] = item
                }
                continue
            }
            if baseURL != "https://api.jup.ag",
               let decoded = await fetchChunk(mints: chunk, base: "https://api.jup.ag") {
                for (mint, item) in decoded {
                    result[mint] = item
                }
            }
        }
        return result
    }

    private func fetchChunk(mints: [String], base: String) async -> [String: JupPriceItem]? {
        // 1) Try GET (works on api.jup.ag).
        var components = URLComponents(string: base)
        components?.path = "/price/v3"
        components?.queryItems = [
            URLQueryItem(name: "ids", value: mints.joined(separator: ","))
        ]
        if let url = components?.url {
            var getRequest = URLRequest(url: url)
            getRequest.httpMethod = "GET"
            getRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            if let decoded = await performDecode(request: getRequest) {
                return decoded
            }
        }

        // 2) Fallback to POST for rpc.jup.bar proxies that reject GET.
        guard let postURL = URL(string: "\(base)/price/v3") else { return nil }
        var postRequest = URLRequest(url: postURL)
        postRequest.httpMethod = "POST"
        postRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        postRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        postRequest.httpBody = try? JSONSerialization.data(withJSONObject: ["ids": mints])
        return await performDecode(request: postRequest)
    }

    private func performDecode(request: URLRequest) async -> [String: JupPriceItem]? {
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let decoded = try? JSONDecoder().decode([String: JupPriceItem].self, from: data) {
                return decoded
            }
            if let wrapped = try? JSONDecoder().decode(JupPriceDataWrapper.self, from: data) {
                return wrapped.data
            }
            return nil
        } catch {
            return nil
        }
    }
}

private struct JupPriceDataWrapper: Decodable {
    let data: [String: JupPriceItem]
}

struct JupPriceItem: Decodable {
    let usdPrice: Double?
    let volume24h: Double?
    let marketCap: Double?
    let liquidity: Double?
    let ath: Double?
    let atl: Double?
    let supply: Double?
    let holders: Int?

    enum CodingKeys: String, CodingKey {
        case usdPrice
        case volume24h
        case marketCap
        case liquidity
        case ath
        case atl
        case supply
        case holders
        case volume24hUsd
        case marketCapUsd
        case liquidityUsd
        case circulatingSupply
        case totalSupply
        case holdersCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usdPrice = try container.decodeIfPresent(Double.self, forKey: .usdPrice)
        volume24h = try container.decodeIfPresent(Double.self, forKey: .volume24h)
            ?? container.decodeIfPresent(Double.self, forKey: .volume24hUsd)
        marketCap = try container.decodeIfPresent(Double.self, forKey: .marketCap)
            ?? container.decodeIfPresent(Double.self, forKey: .marketCapUsd)
        liquidity = try container.decodeIfPresent(Double.self, forKey: .liquidity)
            ?? container.decodeIfPresent(Double.self, forKey: .liquidityUsd)
        ath = try container.decodeIfPresent(Double.self, forKey: .ath)
        atl = try container.decodeIfPresent(Double.self, forKey: .atl)
        supply = try container.decodeIfPresent(Double.self, forKey: .supply)
            ?? container.decodeIfPresent(Double.self, forKey: .circulatingSupply)
            ?? container.decodeIfPresent(Double.self, forKey: .totalSupply)
        holders = try container.decodeIfPresent(Int.self, forKey: .holders)
            ?? container.decodeIfPresent(Int.self, forKey: .holdersCount)
    }
}
