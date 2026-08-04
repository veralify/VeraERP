import SwiftUI
import Combine

// MARK: - FilmViewModel

@MainActor
final class FilmViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var films: [Film] = []
    @Published private(set) var currentFilm: Film?
    @Published private(set) var currentMembers: [FilmMember] = []
    @Published private(set) var currentShots: [FilmShot] = []
    @Published private(set) var currentInvite: FilmInvite?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var isPurchasing = false

    // MARK: - Create Film Form State

    @Published var newFilmName: String = ""
    @Published var newFilmShotLimit: Int = 30
    @Published var newFilmMemberLimit: Int = 25
    @Published var newFilmRevealDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

    // MARK: - Pending Join

    /// Populated when the app is opened via a deep link invite.
    @Published var pendingInviteToken: String?
    @Published var isShowingJoinSheet = false

    // MARK: - Services

    private let filmService = FilmService.shared
    private let purchaseManager = FilmPurchaseManager.shared
    private let supabase = SupabaseClient.shared

    // MARK: - Load Films

    func loadFilms() async {
        guard let userID = supabase.currentSession?.user.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            films = try await filmService.fetchFilms(for: userID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadFilm(id: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            currentFilm = try await filmService.fetchFilm(id: id)
            currentMembers = try await filmService.fetchMembers(for: id)
            if currentFilm?.isRevealed == true {
                currentShots = try await filmService.fetchShots(for: id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create Film

    func createFilm() async -> Film? {
        guard !newFilmName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please give your film a name."
            return nil
        }
        guard let userID = supabase.currentSession?.user.id else {
            errorMessage = "You must be signed in to create a film."
            return nil
        }

        // Purchase before creating
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let purchased = try await purchaseManager.purchase(memberLimit: newFilmMemberLimit)
            guard purchased else { return nil }

            let request = CreateFilmRequest(
                name: newFilmName.trimmingCharacters(in: .whitespaces),
                creatorID: userID,
                shotLimit: newFilmShotLimit,
                memberLimit: newFilmMemberLimit,
                revealAt: newFilmRevealDate
            )
            let film = try await filmService.createFilm(request)
            films.insert(film, at: 0)

            // Auto-create an invite immediately
            let invite = try await filmService.createInvite(for: film.id)
            currentInvite = invite
            currentFilm = film
            resetCreateForm()
            return film
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Join Film

    func joinFilm(token: String, displayName: String) async -> Film? {
        isLoading = true
        defer { isLoading = false }
        do {
            let invite = try await filmService.resolveInvite(token: token)
            let userID = supabase.currentSession?.user.id
            let guestToken = guestTokenForDevice()

            // Check if already a member to avoid duplicates
            if let uid = userID, let existing = try? await filmService.fetchMember(filmID: invite.filmID, userID: uid) {
                _ = existing
                throw FilmError.alreadyMember
            }
            if userID == nil, let existing = try? await filmService.fetchGuestMember(filmID: invite.filmID, guestToken: guestToken) {
                _ = existing
                throw FilmError.alreadyMember
            }

            _ = try await filmService.joinFilm(
                filmID: invite.filmID,
                userID: userID,
                guestToken: userID == nil ? guestToken : nil,
                displayName: displayName
            )
            let film = try await filmService.fetchFilm(id: invite.filmID)
            currentFilm = film
            if !films.contains(where: { $0.id == film.id }) { films.insert(film, at: 0) }
            return film
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Invite

    func loadOrCreateInvite(for filmID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            currentInvite = try await filmService.createInvite(for: filmID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reveal

    /// Checks whether the film's reveal time has passed and reloads if needed.
    func checkReveal() async {
        guard let film = currentFilm else { return }
        if film.isRevealPast && !film.isRevealed {
            await loadFilm(id: film.id)
        }
    }

    // MARK: - Helpers

    private func guestTokenForDevice() -> String {
        if let existing = KeychainManager.shared.load(for: .filmGuestToken) { return existing }
        let token = UUID().uuidString
        KeychainManager.shared.save(token, for: .filmGuestToken)
        return token
    }

    private func resetCreateForm() {
        newFilmName = ""
        newFilmShotLimit = 30
        newFilmMemberLimit = 25
        newFilmRevealDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    }
}
