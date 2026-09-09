import Foundation
import Security

struct R2Connection: Codable {
    let endpoint: URL
    let token: String
}

enum R2Error: LocalizedError {
    case invalidConnection, unauthorized, unavailable, invalidCatalog, keychain
    var errorDescription: String? {
        switch self {
        case .invalidConnection: return "Introduce la URL HTTPS de tu servicio y la clave de acceso."
        case .unauthorized: return "La clave de acceso no es válida."
        case .unavailable: return "No se pudo acceder a la biblioteca. Comprueba la conexión y vuelve a intentarlo."
        case .invalidCatalog: return "La biblioteca devolvió una respuesta no válida."
        case .keychain: return "No se pudo guardar la conexión de forma segura."
        }
    }
}

/// Connection credentials live in the device Keychain, never in the app bundle.
enum R2Credentials {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "SonoCRT.R2",
        kSecAttrAccount as String: "personal-library"
    ]
    static func load() -> R2Connection? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(R2Connection.self, from: data)
    }
    static func save(_ connection: R2Connection) throws {
        let data = try JSONEncoder().encode(connection)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var q = query; attributes.forEach { q[$0.key] = $0.value }
            guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw R2Error.keychain }
        } else if status != errSecSuccess { throw R2Error.keychain }
    }
    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw R2Error.keychain }
    }
}

struct R2Service {
    let connection: R2Connection
    private struct CatalogPage: Decodable {
        struct Object: Decodable { let key: String; let version: String? }
        let objects: [Object]
        let cursor: String?
    }
    private struct PlaybackLink: Decodable { let url: URL }
    private func request<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: connection.endpoint.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
            // URLSearchParams on the server interprets literal + as a space.
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        }
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer " + connection.token, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        // Ephemeral sessions avoid persisting authenticated responses and signed links.
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw R2Error.unavailable }
        if http.statusCode == 401 || http.statusCode == 403 { throw R2Error.unauthorized }
        guard http.statusCode == 200 else { throw R2Error.unavailable }
        guard let result = try? JSONDecoder().decode(T.self, from: data) else { throw R2Error.invalidCatalog }
        return result
    }
    func catalog() async throws -> [Track] {
        var keys: [String: String] = [:]
        var cursor: String?
        var seen = Set<String>()
        repeat {
            try Task.checkCancellation()
            let page: CatalogPage = try await request("catalog", query: cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? [])
            for object in page.objects { keys[object.key] = object.version ?? "" }
            cursor = page.cursor
            if let cursor, !seen.insert(cursor).inserted { throw R2Error.invalidCatalog }
        } while cursor != nil
        return keys.keys.sorted().enumerated().map { index, key in
            Track(id: key, title: URL(fileURLWithPath: key).deletingPathExtension().lastPathComponent, artist: "Artista desconocido", duration: 0, objectKey: key, metadataVersion: keys[key].flatMap { $0.isEmpty ? nil : $0 })
        }
    }
    func playbackURL(for key: String) async throws -> URL {
        let link: PlaybackLink = try await request("play", query: [URLQueryItem(name: "key", value: key)])
        guard link.url.scheme == "https", link.url.host == connection.endpoint.host,
              link.url.port == connection.endpoint.port else { throw R2Error.invalidCatalog }
        return link.url
    }
}
