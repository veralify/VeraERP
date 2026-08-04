import SwiftUI
import StoreKit

// MARK: - CreateFilmView

struct CreateFilmView: View {
    @ObservedObject var viewModel: FilmViewModel
    @Environment(\.dismiss) private var dismiss

    private let memberTiers = [5, 10, 25, 50, 100, 150, 200]
    private let shotOptions = [10, 20, 30, 50, 100]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        nameField
                        revealDatePicker
                        memberLimitPicker
                        shotLimitPicker
                        priceSummary
                        createButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("New Film")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
        }
    }

    // MARK: - Sections

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Film Name", icon: "film")
            TextField("e.g. Sarah's Wedding", text: $viewModel.newFilmName)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var revealDatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Reveal Date", icon: "calendar.badge.clock")
            DatePicker(
                "Reveal Date",
                selection: $viewModel.newFilmRevealDate,
                in: Date.now.addingTimeInterval(3600)...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .tint(AppTheme.accent)
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var memberLimitPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Group Size", icon: "person.2.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(memberTiers, id: \.self) { tier in
                        tierChip(tier)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var shotLimitPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Shots per Person", icon: "camera.fill")
            HStack(spacing: 10) {
                ForEach(shotOptions, id: \.self) { limit in
                    shotChip(limit)
                }
            }
        }
    }

    private var priceSummary: some View {
        let product = FilmPurchaseManager.shared.product(for: viewModel.newFilmMemberLimit)
        return VStack(spacing: 8) {
            Divider()
            HStack {
                Text("Film price")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let product {
                    Text(product.displayPrice)
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                } else {
                    ProgressView().scaleEffect(0.7)
                }
            }
            Text("One-time purchase · no subscription")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
    }

    private var createButton: some View {
        Button {
            Task {
                if let film = await viewModel.createFilm() {
                    _ = film
                    dismiss()
                }
            }
        } label: {
            HStack {
                if viewModel.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Label("Create & Pay", systemImage: "lock.open.fill")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.premiumGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
            .font(.headline)
        }
        .disabled(viewModel.isPurchasing || viewModel.newFilmName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.ink)
    }

    private func tierChip(_ tier: Int) -> some View {
        let selected = viewModel.newFilmMemberLimit == tier
        return Button { viewModel.newFilmMemberLimit = tier } label: {
            VStack(spacing: 2) {
                Text("≤\(tier)")
                    .font(.system(.subheadline, weight: .semibold))
                Text("people")
                    .font(.caption2)
                    .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(selected ? AppTheme.accent : Color.primary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(selected ? .white : AppTheme.ink)
        }
        .buttonStyle(.plain)
    }

    private func shotChip(_ limit: Int) -> some View {
        let selected = viewModel.newFilmShotLimit == limit
        return Button { viewModel.newFilmShotLimit = limit } label: {
            Text("\(limit)")
                .font(.system(.subheadline, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(selected ? AppTheme.accent : Color.primary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(selected ? .white : AppTheme.ink)
        }
        .buttonStyle(.plain)
    }
}
