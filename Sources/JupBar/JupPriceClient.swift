import Foundation

struct JupPriceClient {
    let apiKey: String
    let baseURL: String

    init(apiKey: String, baseURL: String = "https://api.jup.ag") {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    func fetchPrices(mints: [String]) async -> [String: Double] {
        guard !mints.isEmpty else { return [:] }
        var result: [String: Double] = [:]
        let chunks = stride(from: 0, to: mints.count, by: 50).map {
            Array(mints[$0..<min($0 + 50, mints.count)])
        }
        for chunk in chunks {
            if let decoded = await fetchChunk(mints: chunk, base: baseURL) {
                for (mint, item) in decoded {
                    if let price = item.usdPrice {
                        result[mint] = price
                    }
                }
                continue
            }
            if baseURL != "https://api.jup.ag",
               let decoded = await fetchChunk(mints: chunk, base: "https://api.jup.ag") {
                for (mint, item) in decoded {
                    if let price = item.usdPrice {
                        result[mint] = price
                    }
                }
            }
        }
        return result
    }

    private func fetchChunk(mints: [String], base: String) async -> [String: JupPriceItem]? {
        var components = URLComponents(string: base)
        components?.path = "/price/v3"
        components?.queryItems = [
            URLQueryItem(name: "ids", value: mints.joined(separator: ","))
        ]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode([String: JupPriceItem].self, from: data)
        } catch {
            return nil
        }
    }
}

struct JupPriceItem: Decodable {
    let usdPrice: Double?
}
