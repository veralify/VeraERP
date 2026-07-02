import SwiftUI

struct CountryDetailView: View {
    let country: Country
    @StateObject private var viewModel = CountryDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading plans…")
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    "Couldn't Load Plans",
                    systemImage: "wifi.slash",
                    description: Text(error)
                )
            } else if viewModel.packages.isEmpty {
                ContentUnavailableView(
                    "No Plans Available",
                    systemImage: "simcard.fill",
                    description: Text("No eSIM plans are available for \(country.name) right now.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.packages) { pkg in
                            NavigationLink(destination: PlanDetailView(package: pkg, country: country)) {
                                PackageRow(package: pkg)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("\(country.flagEmoji) \(country.name)")
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.load(countryCode: country.code) }
    }
}

#Preview {
    NavigationStack {
        CountryDetailView(country: Country(code: "FR", name: "France"))
    }
}
