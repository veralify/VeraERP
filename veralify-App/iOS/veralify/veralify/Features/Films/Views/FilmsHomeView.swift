import SwiftUI

// MARK: - FilmsHomeView

struct FilmsHomeView: View {
    @EnvironmentObject private var viewModel: FilmViewModel
    @State private var isShowingCreate = false
    @State private var selectedFilm: Film?
    @State private var joinDisplayName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                if viewModel.isLoading && viewModel.films.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.films.isEmpty {
                    emptyState
                } else {
                    filmList
                }
            }
            .navigationTitle("Films")
            .toolbar { createButton }
            .sheet(isPresented: $isShowingCreate) {
                CreateFilmView(viewModel: viewModel)
            }
            .sheet(item: $selectedFilm) { film in
                FilmDetailView(filmID: film.id)
            }
            .sheet(isPresented: $viewModel.isShowingJoinSheet) {
                joinSheet
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
        }
        .task { await viewModel.loadFilms() }
        .onAppear { loadProductsIfNeeded() }
        .onChange(of: viewModel.pendingInviteToken) { _, token in
            if token != nil { viewModel.isShowingJoinSheet = true }
        }
    }

    // MARK: - Subviews

    private var filmList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.films) { film in
                    Button { selectedFilm = film } label: {
                        FilmCardView(film: film)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 90) // nav bar clearance
        }
        .refreshable { await viewModel.loadFilms() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.accent)

            Text("No films yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            Text("Create a film, invite your group, and\ndiscover the shots together at reveal.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Create your first film") {
                isShowingCreate = true
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder
    private var createButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("New Film", systemImage: "plus") {
                isShowingCreate = true
            }
            .tint(AppTheme.accent)
        }
    }

    private var joinSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.accent)

                Text("Join Film")
                    .font(.title2.weight(.bold))

                Text("Enter your name so other members know who's shooting.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Your name", text: $joinDisplayName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Button("Join") {
                    guard let token = viewModel.pendingInviteToken else { return }
                    Task {
                        if let film = await viewModel.joinFilm(token: token, displayName: joinDisplayName) {
                            viewModel.pendingInviteToken = nil
                            viewModel.isShowingJoinSheet = false
                            selectedFilm = film
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(joinDisplayName.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Join a Film")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.pendingInviteToken = nil
                        viewModel.isShowingJoinSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadProductsIfNeeded() {
        Task { await FilmPurchaseManager.shared.loadProducts() }
    }
}
