import SwiftUI
import VeralifyCore

/// Navigation value for the mileage screen.
struct MileageRoute: Hashable {}

/// Business journeys in your own vehicle, and what they can be claimed at.
///
/// Trips live on the server only (there is no SwiftData model for them): each
/// one is written together with the expense transaction it claims, and that
/// transaction reaches the phone through the normal sync. So this screen
/// reads and writes through PostgREST directly and needs a connection.
struct MileageView: View {
    @State private var trips: [MileageTrip] = []
    @State private var phase: Phase = .loading
    @State private var isAdding = false
    @State private var deleting: MileageTrip?

    enum Phase: Equatable {
        case loading
        case loaded
        case failed
    }

    private var yearTrips: [MileageTrip] {
        let year = Calendar.current.component(.year, from: .now)
        return trips.filter { Calendar.current.component(.year, from: $0.date) == year }
    }

    /// Claimed this calendar year, per currency, largest first.
    private var claimedThisYear: [(currency: String, total: Decimal)] {
        Dictionary(grouping: yearTrips, by: \.currency)
            .map { (currency: $0.key, total: $0.value.reduce(Decimal(0)) { $0 + $1.claimed }) }
            .sorted { $0.total > $1.total }
    }

    private var businessMilesThisTaxYear: Decimal {
        Mileage.priorBusinessMiles(before: .now, trips: trips.map {
            (date: $0.date, distance: $0.distance, unit: $0.unit, isBusiness: $0.isBusiness)
        })
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    switch phase {
                    case .loading:
                        ProgressView()
                            .tint(Theme.lime)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    case .failed:
                        EmptyStateView(
                            icon: "wifi.exclamationmark",
                            title: "Trips could not be loaded",
                            message: "Mileage needs a connection and a signed-in account. Pull down to try again."
                        )
                    case .loaded:
                        if trips.isEmpty {
                            EmptyStateView(
                                icon: "car.fill",
                                title: "No trips yet",
                                message: "Log a business journey and it is added to your expenses at the rate you choose."
                            )
                            PrimaryButton(title: "Log your first trip", enabled: true) { isAdding = true }
                                .padding(.horizontal, 4)
                        } else {
                            summary
                            tripList
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .refreshable { await load() }
        }
        .navigationTitle("Mileage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: {
                    Label("Log trip", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.lime)
                }
                .buttonStyle(.pressable)
            }
        }
        .task { await load() }
        .sheet(isPresented: $isAdding) {
            MileageTripSheet(existingTrips: trips) { await load() }
                .presentationBackground(Theme.background)
        }
        .confirmationDialog(
            "Delete this trip?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { trip in
            Button("Delete", role: .destructive) { Task { await delete(trip) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("The trip and the expense it created are both removed.")
        }
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Claimed this year")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.onAccent.opacity(0.8))
            Text(claimedThisYear.map { Self.money($0.total, $0.currency) }.joined(separator: " · "))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.onAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    Text("\(yearTrips.count) trips")
                    Text("·")
                    Text("\(Self.distance(businessMilesThisTaxYear)) of 10,000 business miles this tax year")
                }
                .lineLimit(1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(yearTrips.count) trips")
                    Text("\(Self.distance(businessMilesThisTaxYear)) of 10,000 business miles this tax year")
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.onAccent.opacity(0.8))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.lime, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Trips

    private var tripList: some View {
        GroupedCard {
            ForEach(Array(trips.enumerated()), id: \.element.id) { index, trip in
                if index > 0 { RowDivider() }
                row(trip)
                    .contextMenu {
                        Button(role: .destructive) { deleting = trip } label: {
                            Label("Delete trip", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private func row(_ trip: MileageTrip) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.title(for: trip))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(trip.date.formatted(.dateTime.day().month(.abbreviated).year())) · \(Self.distance(trip.distance)) \(trip.unit.rawValue)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                Pill(
                    text: trip.isBusiness ? String(localized: "Business") : String(localized: "Personal"),
                    style: .muted(dot: trip.isBusiness ? Theme.blue : Theme.textTertiary)
                )
                .fixedSize()
                .padding(.top, 2)
            }
            Spacer(minLength: 8)
            Text(Self.money(trip.claimed, trip.currency))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .padding(.vertical, 14)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text("Delete trip")) { deleting = trip }
    }

    // MARK: - Loading

    private func load() async {
        do {
            let api = MileageAPI(session: try Backend.require())
            trips = try await api.trips()
            phase = .loaded
        } catch {
            if trips.isEmpty { phase = .failed }
        }
    }

    private func delete(_ trip: MileageTrip) async {
        deleting = nil
        do {
            let api = MileageAPI(session: try Backend.require())
            try await api.delete(trip.id)
            trips.removeAll { $0.id == trip.id }
        } catch {
            await load()
        }
    }

    // MARK: - Formatting

    static func title(for trip: MileageTrip) -> String {
        if !trip.origin.isEmpty && !trip.destination.isEmpty {
            return "\(trip.origin) → \(trip.destination)"
        }
        return trip.purpose.isEmpty ? String(localized: "Trip") : trip.purpose
    }

    /// In the trip's own currency, with the same en_US separators as `CurrencyFormat`.
    static func money(_ amount: Decimal, _ currency: String) -> String {
        amount.formatted(
            .currency(code: currency)
                .locale(Locale(identifier: "en_US"))
                .precision(.fractionLength(2))
        )
    }

    static func distance(_ value: Decimal) -> String {
        value.formatted(.number.locale(Locale(identifier: "en_US")).precision(.fractionLength(0...1)))
    }
}

// MARK: - Log a trip

/// The trip form. A preset fills the rate, unit and currency; every field
/// stays editable, and the amount shown is exactly what will be saved.
struct MileageTripSheet: View {
    /// Trips already logged, for the UK band's running total of business miles.
    let existingTrips: [MileageTrip]
    let onSaved: @MainActor () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var preset: MileageRatePreset
    @State private var date = Date.now
    @State private var origin = ""
    @State private var destination = ""
    @State private var distance = ""
    @State private var unit: DistanceUnit
    @State private var rate: String
    @State private var rateAfter: String
    @State private var currency: String
    @State private var purpose = ""
    @State private var isBusiness = true
    @State private var isSaving = false
    @State private var failed = false

    init(existingTrips: [MileageTrip], onSaved: @escaping @MainActor () async -> Void) {
        self.existingTrips = existingTrips
        self.onSaved = onSaved
        let initial: MileageRatePreset = switch AppSettings.currencyCode {
        case "GBP": .ukCar
        case "EUR": .italyACI
        default: .custom
        }
        _preset = State(initialValue: initial)
        _unit = State(initialValue: initial.unit)
        _rate = State(initialValue: initial.rate.map(\.editableText) ?? "")
        _rateAfter = State(initialValue: initial.band?.rateAfter.editableText ?? "")
        _currency = State(initialValue: initial.id == "custom" ? AppSettings.currencyCode : initial.currency)
    }

    private var parsedDistance: Decimal? { AmountParser.parse(distance).flatMap { $0 > 0 ? $0 : nil } }
    private var parsedRate: Decimal? { AmountParser.parse(rate) }
    private var parsedRateAfter: Decimal? { AmountParser.parse(rateAfter) }
    private var normalisedCurrency: String { currency.trimmingCharacters(in: .whitespaces).uppercased() }

    private var band: MileageBand? {
        guard let presetBand = preset.band, let parsedRateAfter else { return nil }
        return MileageBand(limitMiles: presetBand.limitMiles, rateAfter: parsedRateAfter)
    }

    private var quote: MileageAmount? {
        guard let parsedDistance, let parsedRate else { return nil }
        let prior = Mileage.priorBusinessMiles(before: date, trips: existingTrips.map {
            (date: $0.date, distance: $0.distance, unit: $0.unit, isBusiness: $0.isBusiness)
        })
        return Mileage.amount(
            distance: parsedDistance,
            unit: unit,
            rate: parsedRate,
            band: band,
            priorBusinessMiles: prior,
            isBusiness: isBusiness
        )
    }

    private var canSave: Bool {
        quote != nil
            && (preset.band == nil || parsedRateAfter != nil)
            && normalisedCurrency.count == 3
            && normalisedCurrency.allSatisfy { $0.isASCII && $0.isLetter }
            && !isSaving
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        presetPicker

                        VStack(spacing: 14) {
                            DateField(label: "Date", date: $date)
                            FieldRow(label: "From", placeholder: "Office", text: $origin)
                            FieldRow(label: "To", placeholder: "Client site", text: $destination)
                            HStack(alignment: .bottom, spacing: 10) {
                                FieldRow(label: "Distance", placeholder: "0", text: $distance, keyboard: .decimalPad)
                                Picker("Unit", selection: $unit) {
                                    Text("km").tag(DistanceUnit.km)
                                    Text("mi").tag(DistanceUnit.mi)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 110)
                                .padding(.bottom, 8)
                            }
                        }
                        .padding(16)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))

                        VStack(spacing: 14) {
                            FieldRow(
                                label: preset.band == nil ? "Rate per unit" : "Rate per mile, first 10,000",
                                placeholder: "0.00",
                                text: $rate,
                                keyboard: .decimalPad
                            )
                            if preset.band != nil {
                                FieldRow(
                                    label: "Rate per mile after 10,000",
                                    placeholder: "0.00",
                                    text: $rateAfter,
                                    keyboard: .decimalPad
                                )
                            }
                            FieldRow(label: "Currency", placeholder: "EUR", text: $currency)
                            FieldRow(label: "Purpose", placeholder: "Client meeting", text: $purpose)
                            Toggle(isOn: $isBusiness) {
                                Text("Business trip")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            .tint(Theme.lime)
                        }
                        .padding(16)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))

                        if let quote {
                            quoteCard(quote)
                        }

                        if failed {
                            Text("The trip could not be saved. Check your connection and try again.")
                                .font(.footnote)
                                .foregroundStyle(Theme.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        PrimaryButton(title: "Log trip", enabled: canSave) { Task { await save() } }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .dismissibleKeyboard()
            }
            .navigationTitle("Log a trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(MileageRatePreset.all) { option in
                        Button { apply(option) } label: {
                            Text(Self.presetName(option))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(preset.id == option.id ? Theme.onAccent : Theme.textSecondary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 9)
                                .background(preset.id == option.id ? Theme.lime : Theme.surfaceElevated, in: .capsule)
                                .frame(minHeight: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()

            Text(Self.presetNote(preset))
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func quoteCard(_ quote: MileageAmount) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("You can claim")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 8)
                Text(MileageView.money(quote.amount, normalisedCurrency.count == 3 ? normalisedCurrency : "EUR"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.lime)
            }
            if quote.milesAfterBand > 0 {
                Text("\(MileageView.distance(quote.milesAfterBand)) miles of this trip are past 10,000 this tax year, at the lower rate.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    private func apply(_ option: MileageRatePreset) {
        preset = option
        unit = option.unit
        if let presetRate = option.rate { rate = presetRate.editableText } else if option.id == "it_aci" { rate = "" }
        rateAfter = option.band?.rateAfter.editableText ?? ""
        if option.id != "custom" { currency = option.currency }
    }

    private func save() async {
        guard let quote, let parsedDistance else { return }
        isSaving = true
        failed = false
        defer { isSaving = false }
        let trip = NewMileageTrip(
            id: UUID(),
            date: date,
            origin: origin.trimmingCharacters(in: .whitespacesAndNewlines),
            destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
            distance: parsedDistance,
            unit: unit,
            ratePerUnit: quote.effectiveRate,
            amount: quote.amount,
            currency: normalisedCurrency,
            purpose: purpose.trimmingCharacters(in: .whitespacesAndNewlines),
            isBusiness: isBusiness
        )
        do {
            try await MileageAPI(session: try Backend.require()).log(trip)
            await onSaved()
            dismiss()
        } catch {
            failed = true
        }
    }

    static func presetName(_ preset: MileageRatePreset) -> String {
        switch preset.id {
        case "uk_car": String(localized: "UK car or van")
        case "uk_motorcycle": String(localized: "UK motorcycle")
        case "uk_bicycle": String(localized: "UK bicycle")
        case "it_aci": String(localized: "Italy (ACI)")
        default: String(localized: "Custom")
        }
    }

    static func presetNote(_ preset: MileageRatePreset) -> String {
        switch preset.id {
        case "uk_car": String(localized: "HMRC: 45p a mile for the first 10,000 business miles this tax year, then 25p.")
        case "uk_motorcycle": String(localized: "HMRC: 24p a mile.")
        case "uk_bicycle": String(localized: "HMRC: 20p a mile.")
        case "it_aci": String(localized: "Enter the rate per km for your vehicle from the ACI tables. It depends on make, model and fuel.")
        default: String(localized: "Any rate per km or per mile, in any currency.")
        }
    }
}
