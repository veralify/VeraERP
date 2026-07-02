import Foundation
import SwiftUI
import Combine

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Where are you going?", text: $viewModel.searchText)
                        .autocapitalization(.none)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Category tabs
                Picker("Category", selection: $viewModel.selectedCategory) {
                    ForEach(PlanCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 12)

                // Content
                switch viewModel.selectedCategory {
                case .local:
                    CountriesGrid(
                        countries: viewModel.filteredCountries,
                        searchText: viewModel.searchText
                    )
                case .regional:
                    PackagesList(
                        packages: viewModel.regionalPackages,
                        isLoading: viewModel.isLoadingGlobal,
                        emptyTitle: "No Regional Plans",
                        category: .regional
                    )
                    .task { await viewModel.loadGlobalPackages() }
                case .global:
                    PackagesList(
                        packages: viewModel.worldwidePackages,
                        isLoading: viewModel.isLoadingGlobal,
                        emptyTitle: "No Global Plans",
                        category: .global
                    )
                    .task { await viewModel.loadGlobalPackages() }
                }
            }
            .navigationTitle(AppConfig.appName)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Countries Grid

private struct CountriesGrid: View {
    let countries: [Country]
    let searchText: String

    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 12)]

    var body: some View {
        ScrollView {
            if countries.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(countries) { country in
                        NavigationLink(destination: CountryDetailView(country: country)) {
                            CountryCard(country: country)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }
}

private struct CountryCard: View {
    let country: Country

    var body: some View {
        VStack(spacing: 6) {
            Text(country.flagEmoji)
                .font(.system(size: 36))
            Text(country.name)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Packages List (Regional / Global)

private struct PackagesList: View {
    let packages: [ESIMPackage]
    let isLoading: Bool
    let emptyTitle: String
    let category: PlanCategory

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading plans…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if packages.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "simcard.2.fill",
                    description: Text("No plans available right now.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(packages) { pkg in
                            // Regional/Global packages cover multiple countries — no single country context
                            let dummyCountry = Country(
                                code: pkg.countries.first ?? "XX",
                                name: pkg.planCategory == .global ? "Worldwide" : "Multi-country"
                            )
                            NavigationLink(destination: PlanDetailView(package: pkg, country: dummyCountry)) {
                                PackageRow(package: pkg)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct PackageRow: View {
    let package: ESIMPackage

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(package.data)
                    .font(.title3.bold())
                Text(package.validityText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(package.operatorName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(package.formattedPrice)
                .font(.title3.bold())
                .foregroundStyle(.tint)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ExploreView()
}
