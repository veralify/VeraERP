import SwiftUI

// MARK: - FilmDetailView

struct FilmDetailView: View {
    let filmID: String

    @StateObject private var viewModel = FilmViewModel()
    @State private var isShowingCamera = false
    @State private var isShowingInvite = false
    @State private var isShowingReveal = false
    @Environment(\.dismiss) private var dismiss

    private var film: Film? { viewModel.currentFilm }
    private var currentMember: FilmMember? {
        let userID = SupabaseClient.shared.currentSession?.user.id
        let guestToken = KeychainManager.shared.load(for: .filmGuestToken)
        return viewModel.currentMembers.first {
            if let uid = userID { return $0.userID == uid }
            if let gt = guestToken { return $0.guestToken == gt }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                if viewModel.isLoading && film == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let film {
                    content(for: film)
                }
            }
            .navigationTitle(film?.name ?? "Film")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .sheet(isPresented: $isShowingInvite) {
                if let invite = viewModel.currentInvite, let film {
                    FilmInviteView(invite: invite, filmName: film.name)
                }
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                if let film, let member = currentMember {
                    FilmCameraView(film: film, member: member)
                }
            }
            .fullScreenCover(isPresented: $isShowingReveal) {
                if let film {
                    RevealView(shots: viewModel.currentShots, filmName: film.name)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
        }
        .task {
            await viewModel.loadFilm(id: filmID)
            await viewModel.loadOrCreateInvite(for: filmID)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for film: Film) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                filmHeader(film)

                if film.isRevealed {
                    revealedSection(film)
                } else {
                    preRevealSection(film)
                }

                membersSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 90)
        }
        .refreshable { await viewModel.loadFilm(id: filmID) }
    }

    private func filmHeader(_ film: Film) -> some View {
        VStack(spacing: 8) {
            Image(systemName: film.isRevealed ? "photo.stack.fill" : "camera.aperture")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.accent)
                .padding(.bottom, 4)

            Text(film.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            Label(
                film.isRevealed ? "Revealed" : film.revealAt.formatted(date: .long, time: .shortened),
                systemImage: film.isRevealed ? "checkmark.seal.fill" : "calendar"
            )
            .font(.subheadline)
            .foregroundStyle(film.isRevealed ? AppTheme.accent : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func preRevealSection(_ film: Film) -> some View {
        VStack(spacing: 20) {
            RevealBlurView(revealAt: film.revealAt) {
                Task { await viewModel.loadFilm(id: filmID) }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let member = currentMember, member.shotsUsed < film.shotLimit {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Open Camera", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.premiumGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                        .font(.headline)
                }
            }

            HStack {
                statPill(value: "\(film.shotLimit)", label: "shots / person", icon: "camera")
                statPill(value: "\(viewModel.currentMembers.count)", label: "members", icon: "person.2")
            }
        }
    }

    private func revealedSection(_ film: Film) -> some View {
        VStack(spacing: 16) {
            Button {
                isShowingReveal = true
            } label: {
                Label("See all \(viewModel.currentShots.count) shots", systemImage: "photo.stack.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.premiumGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
                    .font(.headline)
            }

            // 3-column photo thumbnail strip
            if !viewModel.currentShots.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                    ForEach(viewModel.currentShots.prefix(9)) { shot in
                        AsyncImage(url: URL(string: shot.storagePath)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                            default:
                                Rectangle().fill(Color.primary.opacity(0.08))
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Members (\(viewModel.currentMembers.count))", systemImage: "person.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            ForEach(viewModel.currentMembers) { member in
                HStack {
                    Image(systemName: member.isGuest ? "person.fill.questionmark" : "person.crop.circle.fill")
                        .foregroundStyle(.secondary)
                    Text(member.displayName)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text("\(member.shotsUsed) shots")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .premiumCard()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Invite", systemImage: "qrcode") {
                isShowingInvite = true
            }
            .tint(AppTheme.accent)
        }
    }

    // MARK: - Helpers

    private func statPill(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Label(value, systemImage: icon)
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
