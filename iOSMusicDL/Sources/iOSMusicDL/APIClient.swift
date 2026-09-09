import Foundation

final class APIClient: ObservableObject {
    var baseURL: String {
        get { UserDefaults.standard.string(forKey: "serverURL") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "serverURL") }
    }
    var authToken: String {
        get { UserDefaults.standard.string(forKey: "authToken") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "authToken") }
    }

    private func authHeaders() -> [String: String] {
        var h = ["Content-Type": "application/json"]
        if !authToken.isEmpty { h["x-auth-token"] = authToken }
        return h
    }

    func post<T: Decodable>(_ path: String, json: [String: Any], as: T.Type) async throws -> T {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: base + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        for (k, v) in authHeaders() { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            throw URLError(.init(rawValue: http.statusCode))
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func preview(_ url: String) async throws -> Preview {
        try await post("/preview", json: ["url": url], as: Preview.self)
    }

    func download(_ url: String) async throws -> DownloadSummary {
        try await post("/download", json: ["url": url], as: DownloadSummary.self)
    }

    func status(_ session: String) async throws -> DownloadSummary {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: base + "/status/" + session) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        if !authToken.isEmpty { req.setValue(authToken, forHTTPHeaderField: "x-auth-token") }
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(DownloadSummary.self, from: data)
    }

    func fetchFile(_ path: String) async throws -> URL {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let encoded = path.split(separator: "/").map {
            $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
        }.joined(separator: "/")
        guard let url = URL(string: base + "/" + encoded) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        if !authToken.isEmpty { req.setValue(authToken, forHTTPHeaderField: "x-auth-token") }
        let (data, _) = try await URLSession.shared.data(for: req)
        let fileName = URL(string: path)?.lastPathComponent ?? "audio"
        let cleanName = fileName.replacingOccurrences(of: " ", with: " ")
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(cleanName)
        try data.write(to: tmp)
        return tmp
    }
}
