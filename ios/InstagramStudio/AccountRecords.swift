import Foundation

struct StudioAccount: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
}

struct AccountRecords: Codable {
    var accounts: [StudioAccount] = []
    var selectedID: UUID?

    static func load(from url: URL) throws -> AccountRecords {
        guard FileManager.default.fileExists(atPath: url.path) else { return AccountRecords() }
        return try JSONDecoder().decode(AccountRecords.self, from: Data(contentsOf: url))
    }

    func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }

    mutating func add(name: String) throws -> StudioAccount {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= 60 else { throw StudioError.message("Use an account name of 1–60 characters.") }
        let account = StudioAccount(id: UUID(), name: cleaned)
        accounts.append(account)
        return account
    }
}

enum StudioError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(message) = self { return message }; return nil }
}

enum InstagramLink {
    static func post(_ value: String) throws -> URL {
        guard var parts = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme?.lowercased() == "https",
              ["instagram.com", "www.instagram.com"].contains(parts.host?.lowercased() ?? ""),
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.path.range(of: "^/(p|reel|reels)/[A-Za-z0-9_-]+/?$", options: .regularExpression) != nil
        else { throw StudioError.message("Paste an HTTPS Instagram post or Reel link.") }
        parts.host = "www.instagram.com"
        parts.path = parts.path.replacingOccurrences(of: "/reels/", with: "/reel/")
        parts.query = nil; parts.fragment = nil
        guard let result = parts.url else { throw StudioError.message("Invalid link.") }
        return result
    }
}
