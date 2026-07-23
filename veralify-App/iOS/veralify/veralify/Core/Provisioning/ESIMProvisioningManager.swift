//
//  ESIMProvisioningManager.swift
//  veralify
//
//  Native "1-Tap eSIM Direct Installation" using Apple's CoreTelephony
//  in-app provisioning API (CTCellularPlanProvisioning). This bypasses
//  the QR-code flow entirely: iOS shows its own system sheet to perform
//  the over-the-air (OTA) SM-DP+ handshake and install the profile,
//  while our app only supplies the two identifiers eSIM Go gives us
//  after a successful order:
//
//      eSIM Go `ESIMGoInstalledESIM.smdpAddress`  -> CTCellularPlanProvisioningRequest.address
//      eSIM Go `ESIMGoInstalledESIM.matchingId`   -> CTCellularPlanProvisioningRequest.matchingID
//
//  See: Models/ESIMGoModels.swift -> ESIMGoInstalledESIM
//  See: Core/Network/ESIMGoClient.swift -> getInstallDetails(reference:)
//

import CoreTelephony
import SwiftUI
import UIKit
import Combine

// MARK: - Installation State

/// Drives all UI state for the 1-Tap install card. Kept as a simple,
/// `Equatable` value type (using a `String` failure reason rather than
/// `Error`) so SwiftUI can diff it cheaply and drive animations/haptics
/// from `onChange(of:)`.
enum ESIMInstallationState: Equatable {
    case idle
    case installing
    case success
    case failed(reason: String)

    var isInstalling: Bool {
        if case .installing = self { return true }
        return false
    }
}

// MARK: - eSIM Provisioning Manager

/// Thread-safe wrapper around `CTCellularPlanProvisioning`.
///
/// - All CoreTelephony calls are made on a background-safe path per Apple's
///   documented behavior (the OS itself hops to the right queues internally
///   for the provisioning UI); we only guarantee that **our** published
///   state mutations happen on the main actor, since `@Published` values
///   drive SwiftUI.
/// - `CTCellularPlanProvisioning` itself does not require manual locking;
///   it is safe to allocate per-call. We keep a single instance for
///   clarity and to mirror how you'd typically retain other CoreTelephony
///   objects for the lifetime of a provisioning attempt.
@MainActor
final class ESIMProvisioningManager: ObservableObject {

    static let shared = ESIMProvisioningManager()

    /// Current installation state, observed by the SwiftUI action card.
    @Published private(set) var state: ESIMInstallationState = .idle

    /// Cached compatibility check result. `CTCellularPlanProvisioning`
    /// documents `supportsCellularPlan()` as safe to call repeatedly, but
    /// we cache since it doesn't change during a single app session and
    /// the card may query it on every render.
    private var cachedCompatibility: Bool?

    private let provisioning = CTCellularPlanProvisioning()

    private init() {}

    // MARK: Compatibility

    /// Returns `true` when the current device + carrier entitlement combo
    /// supports Apple's in-app eSIM provisioning UI (no QR code needed).
    ///
    /// Important: `CTCellularPlanProvisioningRequest` is documented by
    /// Apple as "only available to carrier apps with suitable
    /// entitlements." In practice this means:
    ///  - Your app must be granted the `com.apple.external-accessory
    ///    .esim-installation` (carrier) entitlement by Apple — a manual
    ///    approval process, not something enabled purely by code.
    ///  - Even with the entitlement, this will be `false` on devices
    ///    without eSIM hardware (e.g. iPads, older iPhones) and always
    ///    `false` in the Simulator.
    ///  - Without the entitlement, `supportsCellularPlan()` reliably
    ///    returns `false`, which is exactly why this feature must always
    ///    ship alongside the QR/manual fallback in production.
    func checkDeviceCompatibility() -> Bool {
        if let cachedCompatibility {
            return cachedCompatibility
        }
        let supported = provisioning.supportsCellularPlan()
        cachedCompatibility = supported
        return supported
    }

    /// Forces a fresh compatibility check, bypassing the cache. Useful if
    /// the app comes back to foreground after a Settings change.
    func refreshDeviceCompatibility() -> Bool {
        cachedCompatibility = nil
        return checkDeviceCompatibility()
    }

    // MARK: Installation (async)

    /// Presents Apple's native eSIM installation sheet and drives `state`
    /// through `.installing` -> `.success` / `.failed`.
    ///
    /// - Parameters:
    ///   - smdpAddress: eSIM Go's `smdpAddress` (e.g. `"rsp.esim-go.com"`),
    ///     taken from `ESIMGoInstalledESIM.smdpAddress` after `placeOrder`.
    ///   - matchingId: eSIM Go's `matchingId`, taken from
    ///     `ESIMGoInstalledESIM.matchingId`.
    ///   - confirmationCode: Optional. Only required if the eSIM profile
    ///     was configured with a confirmation code (rare for eSIM Go
    ///     consumer bundles, but the API supports it).
    ///   - iccid: Optional hint to iOS about which existing eSIM slot to
    ///     target when the device already has a matching, uninstalled
    ///     profile queued. Safe to omit.
    @discardableResult
    func installProfile(
        smdpAddress: String,
        matchingId: String,
        confirmationCode: String? = nil,
        iccid: String? = nil
    ) async -> ESIMInstallationState {
        guard checkDeviceCompatibility() else {
            state = .failed(reason: "This device or carrier doesn't support in-app eSIM installation.")
            return state
        }

        state = .installing

        // Build the native request. These three properties are the exact
        // fields Apple's Local Profile Assistant (LPA) needs to perform
        // the SM-DP+ handshake — the same values that would otherwise be
        // encoded into the QR code's `LPA:1$<address>$<matchingID>` string.
        let request = CTCellularPlanProvisioningRequest()
        request.address = smdpAddress
        request.matchingID = matchingId
        if let confirmationCode {
            request.confirmationCode = confirmationCode
        }
        if let iccid {
            request.iccid = iccid
        }

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<CTCellularPlanProvisioningAddPlanResult, Never>) in
            // `addPlan(with:completionHandler:)` presents the system UI and
            // invokes the handler once the user finishes (or cancels) the
            // flow. Apple's documentation notes the handler may be called
            // on a background queue, so we hop back to the main actor
            // before touching `@Published` state.
            provisioning.addPlan(with: request) { addResult in
                continuation.resume(returning: addResult)
            }
        }

        applyResult(result)
        return state
    }

    /// Completion-handler variant for call sites that aren't using
    /// Swift Concurrency (e.g. older UIKit view controllers).
    func installProfile(
        smdpAddress: String,
        matchingId: String,
        confirmationCode: String? = nil,
        iccid: String? = nil,
        completion: @escaping (ESIMInstallationState) -> Void
    ) {
        guard checkDeviceCompatibility() else {
            let failure = ESIMInstallationState.failed(
                reason: "This device or carrier doesn't support in-app eSIM installation."
            )
            state = failure
            completion(failure)
            return
        }

        state = .installing

        let request = CTCellularPlanProvisioningRequest()
        request.address = smdpAddress
        request.matchingID = matchingId
        if let confirmationCode {
            request.confirmationCode = confirmationCode
        }
        if let iccid {
            request.iccid = iccid
        }

        provisioning.addPlan(with: request) { [weak self] addResult in
            // Per Apple's docs, this handler may fire on a background
            // queue — dispatch back to the main actor before publishing.
            Task { @MainActor in
                guard let self else { return }
                self.applyResult(addResult)
                completion(self.state)
            }
        }
    }

    /// Resets state back to `.idle`, e.g. after the user dismisses a
    /// success/failure banner and wants to try again.
    func reset() {
        state = .idle
    }

    // MARK: Private

    private func applyResult(_ result: CTCellularPlanProvisioningAddPlanResult) {
        switch result {
        case .success:
            state = .success
        case .cancel:
            // User backed out of the native sheet — treat as idle rather
            // than an error so the UI doesn't show a scary failure banner.
            state = .idle
        case .fail:
            state = .failed(reason: "The carrier couldn't complete activation. Please try again or use manual setup.")
        case .unknown:
            state = .failed(reason: "Something went wrong communicating with your carrier.")
        @unknown default:
            state = .failed(reason: "Unexpected provisioning result.")
        }
    }
}

// MARK: - Premium SwiftUI Action Card

/// Drop this into the "Install" section in place of (or above) the QR
/// code flow. It automatically adapts:
///  - Device supports in-app install → pulsing gradient "1-Tap" button.
///  - Device doesn't support it → clean fallback banner pointing users
///    to the manual/QR setup instead.
struct ESIMInstantSetupCard: View {
    /// eSIM Go's `smdpAddress` for this order (e.g. "rsp.esim-go.com").
    let smdpAddress: String
    /// eSIM Go's `matchingId` for this order.
    let matchingId: String
    /// Invoked when the user should be routed to the manual/QR fallback
    /// UI (either because the device is incompatible, or the native
    /// install failed).
    var onShowManualSetup: () -> Void = {}

    @StateObject private var manager = ESIMProvisioningManager.shared
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isSupported: Bool {
        manager.checkDeviceCompatibility()
    }

    var body: some View {
        Group {
            if isSupported {
                supportedCard
            } else {
                unsupportedBanner
            }
        }
        .animation(.easeInOut(duration: 0.3), value: manager.state)
        .onChange(of: manager.state) { _, newState in
            handleStateChangeHaptics(newState)
        }
    }

    // MARK: Supported device

    private var supportedCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Instant Setup Available")
                        .font(.headline)
                    Text("Skip the QR code — activate in one tap.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            actionButton

            statusMessage
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var actionButton: some View {
        Button {
            triggerInstall()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(installGradient)
                    .shadow(color: AppTheme.accent.opacity(reduceMotion ? 0 : (isPulsing ? 0.55 : 0.25)), radius: isPulsing ? 16 : 8)

                if manager.state.isInstalling {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label("⚡️ 1-Tap Instant Setup", systemImage: "wand.and.stars")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 54)
        }
        .disabled(manager.state.isInstalling)
        .scaleEffect(isPulsing && !reduceMotion ? 1.015 : 1.0)
        .onAppear { startPulseIfIdle() }
        .onChange(of: manager.state) { _, newState in
            if newState == .idle {
                startPulseIfIdle()
            } else {
                isPulsing = false
            }
        }
    }

    private var installGradient: LinearGradient {
        LinearGradient(
            colors: [AppTheme.accent, AppTheme.accent.opacity(0.75)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var statusMessage: some View {
        switch manager.state {
        case .idle:
            EmptyView()
        case .installing:
            Text("Talking to your carrier — this usually takes a few seconds…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .success:
            Label("eSIM installed successfully!", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
        case .failed(let reason):
            VStack(alignment: .leading, spacing: 8) {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)

                fallbackBanner
            }
        }
    }

    private func startPulseIfIdle() {
        guard manager.state == .idle, !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }

    private func triggerInstall() {
        UINotificationFeedbackGenerator().prepare()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            let result = await manager.installProfile(
                smdpAddress: smdpAddress,
                matchingId: matchingId
            )
            _ = result // haptics + UI react via `onChange(of: manager.state)`
        }
    }

    private func handleStateChangeHaptics(_ state: ESIMInstallationState) {
        switch state {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .failed:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .idle, .installing:
            break
        }
    }

    // MARK: Unsupported device fallback

    private var unsupportedBanner: some View {
        Button(action: onShowManualSetup) {
            HStack(spacing: 12) {
                Image(systemName: "qrcode")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("In-App Setup Unavailable")
                        .font(.subheadline.weight(.semibold))
                    Text("Click here to view manual QR Code setup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Inline fallback link shown underneath a failure message so the
    /// user isn't stuck if native provisioning fails mid-flow.
    private var fallbackBanner: some View {
        Button(action: onShowManualSetup) {
            HStack(spacing: 8) {
                Image(systemName: "qrcode")
                Text("View manual QR Code setup instead")
                    .font(.caption.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Supported device") {
    ESIMInstantSetupCard(
        smdpAddress: "rsp.esim-go.com",
        matchingId: "A1B2-C3D4-E5F6-G7H8"
    )
    .padding()
}
