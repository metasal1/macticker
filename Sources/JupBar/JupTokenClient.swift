import Foundation

struct JupTokenClient {
    let apiKey: String
    let baseURL: String

    init(apiKey: String, baseURL: String = "https://api.jup.ag") {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    func fetchTokens(mints: [String]) async -> [String: JupTokenMeta] {
        guard !mints.isEmpty else { return [:] }
        var result: [String: JupTokenMeta] = [:]
        let chunks = stride(from: 0, to: mints.count, by: 100).map {
            Array(mints[$0..<min($0 + 100, mints.count)])
        }
        for chunk in chunks {
            if let tokens = await fetchChunk(mints: chunk, base: baseURL) {
                for token in tokens {
                    result[token.id] = token
                }
                continue
            }
            if baseURL != "https://api.jup.ag",
               let tokens = await fetchChunk(mints: chunk, base: "https://api.jup.ag") {
                for token in tokens {
                    result[token.id] = token
                }
            }
        }
        return result
    }

    private func fetchChunk(mints: [String], base: String) async -> [JupTokenMeta]? {
        if let tokens = await requestTokens(endpoint: "/tokens/v2/lookup", queryName: "ids", mints: mints, base: base),
           !tokens.isEmpty {
            return tokens
        }
        if let tokens = await requestTokens(endpoint: "/tokens/v2/search", queryName: "query", mints: mints, base: base),
           !tokens.isEmpty {
            return tokens
        }
        return nil
    }

    private func requestTokens(endpoint: String, queryName: String, mints: [String], base: String) async -> [JupTokenMeta]? {
        var components = URLComponents(string: base)
        components?.path = endpoint
        components?.queryItems = [
            URLQueryItem(name: queryName, value: mints.joined(separator: ","))
        ]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return parseTokens(from: data)
        } catch {
            return nil
        }
    }

    private func parseTokens(from data: Data) -> [JupTokenMeta] {
        if let decoded = try? JSONDecoder().decode([JupTokenMeta].self, from: data) {
            return decoded
        }
        if let wrapped = try? JSONDecoder().decode(JupTokenWrapper.self, from: data) {
            return wrapped.tokens
        }
        if let wrapped = try? JSONDecoder().decode(JupTokenDataWrapper.self, from: data) {
            return wrapped.data
        }
        return []
    }
}

struct JupTokenWrapper: Decodable {
    let tokens: [JupTokenMeta]
}

struct JupTokenDataWrapper: Decodable {
    let data: [JupTokenMeta]
}

struct JupTokenMeta: Decodable {
    let id: String
    let name: String?
    let symbol: String?
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case id
        case address
        case name
        case symbol
        case icon
        case logoURI
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idValue = try container.decodeIfPresent(String.self, forKey: .id) {
            id = idValue
        } else if let addressValue = try container.decodeIfPresent(String.self, forKey: .address) {
            id = addressValue
        } else {
            id = ""
        }
        name = try container.decodeIfPresent(String.self, forKey: .name)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        if let iconValue = try container.decodeIfPresent(String.self, forKey: .icon) {
            icon = iconValue
        } else if let logoValue = try container.decodeIfPresent(String.self, forKey: .logoURI) {
            icon = logoValue
        } else {
            icon = nil
        }
    }

    var iconURL: URL? {
        guard let icon, let url = URL(string: icon) else { return nil }
        return url
    }
}
