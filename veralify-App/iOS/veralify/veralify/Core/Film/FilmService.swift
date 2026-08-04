import Foundation

// MARK: - FilmService

/// Handles all Film CRUD and member operations via Supabase (PostgREST + Storage).
@MainActor
final class FilmService {
    static let shared = FilmService()

    private let supabase = SupabaseClient.shared
    private let baseURL: String = AppConfig.supabaseURL

    private init() {}

    // MARK: - ISO8601 Formatter

    private let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private var jsonDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: str) { return date }
            f.formatOptions = [.withInternetDateTime]
            if let date = f.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
        }
        return d
    }

    private var jsonEncoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    // MARK: - Films

    func createFilm(_ request: CreateFilmRequest) async throws -> Film {
        try await supabase.insert(into: "films", data: request, returning: Film.self)
    }

    func fetchFilm(id: String) async throws -> Film {
        let films: [Film] = try await supabase.select(from: "films", filters: ["id": id])
        guard let film = films.first else { throw APIError.notFound }
        return film
    }

    /// Returns all films the given user created or is a member of.
    func fetchFilms(for userID: String) async throws -> [Film] {
        // Fetch films the user created
        let created: [Film] = try await supabase.select(from: "films", filters: ["creator_id": userID])

        // Fetch film IDs the user is a member of
        let memberships: [FilmMember] = try await supabase.select(from: "film_members", filters: ["user_id": userID])
        let memberFilmIDs = memberships.map(\.filmID)

        // Fetch those films if any
        var memberFilms: [Film] = []
        for filmID in memberFilmIDs {
            if let film = try? await fetchFilm(id: filmID) {
                memberFilms.append(film)
            }
        }

        // Merge and deduplicate
        let all = created + memberFilms
        var seen = Set<String>()
        return all.filter { seen.insert($0.id).inserted }
    }

    // MARK: - Invites

    func createInvite(for filmID: String) async throws -> FilmInvite {
        struct InviteRequest: Codable {
            let filmID: String
            let token: String
            enum CodingKeys: String, CodingKey {
                case filmID = "film_id"
                case token
            }
        }
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let _: InviteRequest = try await supabase.insert(into: "film_invites", data: InviteRequest(filmID: filmID, token: token), returning: InviteRequest.self)
        return try await resolveInvite(token: token)
    }

    func resolveInvite(token: String) async throws -> FilmInvite {
        let invites: [FilmInvite] = try await supabase.select(from: "film_invites", filters: ["token": token])
        guard let invite = invites.first else { throw APIError.notFound }
        guard !invite.isExpired else { throw FilmError.inviteExpired }
        return invite
    }

    // MARK: - Members

    func joinFilm(filmID: String, userID: String?, guestToken: String?, displayName: String) async throws -> FilmMember {
        let request = JoinFilmRequest(filmID: filmID, userID: userID, guestToken: guestToken, displayName: displayName)
        return try await supabase.insert(into: "film_members", data: request, returning: FilmMember.self)
    }

    func fetchMembers(for filmID: String) async throws -> [FilmMember] {
        try await supabase.select(from: "film_members", filters: ["film_id": filmID])
    }

    func fetchMember(filmID: String, userID: String) async throws -> FilmMember? {
        let members: [FilmMember] = try await supabase.select(
            from: "film_members",
            columns: "*",
            filters: ["film_id": filmID, "user_id": userID]
        )
        return members.first
    }

    func fetchGuestMember(filmID: String, guestToken: String) async throws -> FilmMember? {
        let members: [FilmMember] = try await supabase.select(
            from: "film_members",
            columns: "*",
            filters: ["film_id": filmID, "guest_token": guestToken]
        )
        return members.first
    }

    func incrementShotsUsed(memberID: String, current: Int) async throws {
        struct ShotCountPatch: Encodable { let shots_used: Int }
        let _: FilmMember = try await supabase.update(
            table: "film_members",
            data: ShotCountPatch(shots_used: current + 1),
            returning: FilmMember.self,
            filters: ["id": memberID]
        )
    }

    // MARK: - Shots

    func recordShot(filmID: String, memberID: String, storagePath: String) async throws -> FilmShot {
        let request = CreateShotRequest(filmID: filmID, memberID: memberID, storagePath: storagePath)
        return try await supabase.insert(into: "film_shots", data: request, returning: FilmShot.self)
    }

    /// Fetches shots only when the film is in `revealed` status.
    func fetchShots(for filmID: String) async throws -> [FilmShot] {
        let film = try await fetchFilm(id: filmID)
        guard film.isRevealed else { throw FilmError.notYetRevealed }
        return try await supabase.select(from: "film_shots", filters: ["film_id": filmID])
    }

    /// Builds a signed Supabase Storage URL valid for 1 hour for a given storage path.
    func signedURL(for storagePath: String) async throws -> URL {
        struct SignedURLRequest: Encodable { let expiresIn: Int; enum CodingKeys: String, CodingKey { case expiresIn = "expiresIn" } }
        struct SignedURLResponse: Decodable { let signedURL: String; enum CodingKeys: String, CodingKey { case signedURL = "signedUrl" } }

        let urlString = "\(AppConfig.supabaseURL)/storage/v1/object/sign/film-shots/\(storagePath)"
        guard let url = URL(string: urlString) else { throw APIError.unknown }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(SignedURLRequest(expiresIn: 3600))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.unknown
        }
        let result = try JSONDecoder().decode(SignedURLResponse.self, from: data)
        guard let signedURL = URL(string: "\(AppConfig.supabaseURL)/storage/v1\(result.signedURL)") else {
            throw APIError.unknown
        }
        return signedURL
    }
}

// MARK: - FilmError

enum FilmError: LocalizedError {
    case notYetRevealed
    case inviteExpired
    case shotLimitReached
    case memberLimitReached
    case alreadyMember

    var errorDescription: String? {
        switch self {
        case .notYetRevealed:    return "Photos unlock on reveal day. Come back then!"
        case .inviteExpired:     return "This invite link has expired."
        case .shotLimitReached:  return "You've used all your shots on this film."
        case .memberLimitReached: return "This film has reached its maximum group size."
        case .alreadyMember:     return "You've already joined this film."
        }
    }
}
