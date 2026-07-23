import Foundation
import SwiftUI
import Combine

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Where are you going?", text: $viewModel.searchText)
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 8)

                Picker("Category", selection: $viewModel.selectedCategory) {
                    ForEach(PlanCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch viewModel.selectedCategory {
                case .local:
                    CountriesGrid(countries: viewModel.filteredCountries, searchText: viewModel.searchText)
                case .regional:
                    PackagesList(packages: viewModel.regionalPackages, isLoading: viewModel.isLoadingGlobal, emptyTitle: "No Regional Plans")
                        .task { await viewModel.loadGlobalPackages() }
                case .global:
                    PackagesList(packages: viewModel.worldwidePackages, isLoading: viewModel.isLoadingGlobal, emptyTitle: "No Global Plans")
                        .task { await viewModel.loadGlobalPackages() }
                }
            }
            .navigationTitle("Get Data")
            .background(AppTheme.screenBackground.ignoresSafeArea())
        }
    }
}

private struct CountriesGrid: View {
    let countries: [Country]
    let searchText: String

    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 140), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Popular Destinations")
                        .font(.headline)
                    Text("Pick a country and activate in minutes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

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
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct CountryCard: View {
    let country: Country

    var body: some View {
        VStack(spacing: 8) {
            Text(country.flagEmoji)
                .font(.system(size: 34))
            Text(country.name)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, minHeight: 98)
        .premiumCard()
    }
}

private struct PackagesList: View {
    let packages: [ESIMPackage]
    let isLoading: Bool
    let emptyTitle: String

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
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

struct PackageRow: View {
    let package: ESIMPackage

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(package.data)
                    .font(.headline)
                Text(package.validityText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(package.operatorName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(package.formattedPrice)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.premiumGradient)
        }
        .premiumCard()
    }
}

#Preview {
    ExploreView()
}
