import SwiftUI

struct FlightCardView: View {
    let flight: FlightOption

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(flight.airline) • \(flight.flightNumber)")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("\(flight.origin) → \(flight.destination)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                Text(flight.formattedPrice)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.green)
            }

            HStack(spacing: 14) {
                Label(flight.departureTime, systemImage: "airplane.departure")
                Label(flight.arrivalTime, systemImage: "airplane.arrival")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.8))

            Text(flight.stops == 0 ? "Non-stop" : "\(flight.stops) stop\(flight.stops > 1 ? "s" : "")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
