import AlarmKit
import AVFoundation
import SwiftUI

/// What the app currently believes, on screen.
///
/// ## Why this exists
/// Every round of debugging on this project has gone: something does not work on device →
/// I guess → an eight minute build → still broken. The device is in Turkey, the developer
/// machine is Windows, there is no debugger and no simulator, and asking someone to fish a
/// crash log out of Settings while an alarm is going off has not worked once.
///
/// So the app answers the questions itself. Every line here is one I have actually had to
/// guess at during a failed round: is the camera allowed, can a capture session even be
/// built on this device, did the alarm chain get six alarms or one, is there a pending
/// proof id sitting in the App Group, is the shared container reachable at all.
///
/// Reached by long-pressing the wordmark — no button, because this is not a feature and
/// nobody should find it by accident. That gesture is written down on nagg.pro/support,
/// which is the only place it needs to be discoverable: it is also where the alarm test
/// now lives, and "does it ring at all" is the first thing support has to establish. It ships in release builds on purpose: the device
/// that matters is not one I can attach anything to, and a diagnostic that only exists in
/// a debug build is a diagnostic that exists nowhere.
struct DiagnosticsView: View {

    let store: CommitmentStore
    let onClose: () -> Void

    @State private var cameraStatus = "checking…"
    @State private var sessionStatus = "checking…"
    @State private var testError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("What the app thinks").naggLabel().padding(.bottom, 10)

                Text("Read this out and the guessing stops.")
                    .font(Nagg.sans(20, .medium))
                    .foregroundStyle(Nagg.ink)
                    .padding(.bottom, 22)

                section("Permissions") {
                    row("Alarms", alarmStatus)
                    row("Camera", cameraStatus)
                    row("Capture session", sessionStatus)
                }

                section("Hand-off") {
                    row("Pending proof id", PendingProof.shared.peek() ?? "none")
                    row("Owed right now", store.commitmentAwaitingProof?.title ?? "nothing")
                    row("App Group", AppGroup.isReachable ? "reachable" : "MISSING")
                    row("Saved file", store.loadFailed ? "UNREADABLE -- do not reinstall" : "read ok")
                }

                section("Commitments (\(store.commitments.count))") {
                    if store.commitments.isEmpty {
                        row("—", "none yet")
                    } else {
                        ForEach(store.commitments) { commitment in
                            commitmentRows(commitment)
                        }
                    }
                }

                // The rehearsal leaves the main screen the moment a real commitment
                // exists, so for most users this is the only way back to it. It belongs
                // here: "does it actually ring" is the same question every other row on
                // this screen exists to answer, and it is the one a support reply needs
                // to be able to point at.
                section("Prove it rings") {
                    Menu {
                        ForEach(Commitment.ProofKind.allCases, id: \.self) { kind in
                            Button {
                                Task { await test(kind) }
                            } label: {
                                Label(kind.label, systemImage: kind.systemImageName)
                            }
                        }
                    } label: {
                        Text("Test the alarm now")
                            .font(Nagg.sans(15, .medium))
                            .foregroundStyle(Nagg.ground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background { RoundedRectangle(cornerRadius: 11).fill(Nagg.ink) }
                    }
                    .disabled(store.rehearsal != nil)
                    .opacity(store.rehearsal == nil ? 1 : 0.4)

                    Text(testError ?? "Rings in 20 seconds, then every 30, five times over. This screen closes so nothing covers it.")
                        .font(Nagg.sans(12))
                        .lineSpacing(3)
                        .foregroundStyle(testError == nil ? Nagg.ink3 : Nagg.alarm)
                        .padding(.top, 6)
                }

                Button("Close", action: onClose)
                    .buttonStyle(NaggGhostButton())
                    .padding(.top, 26)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 26)
        }
        .naggGround()
        .task { await probe() }
    }

    // MARK: - Actions

    /// Arm a rehearsal, then get out of the way. Leaving this sheet up would put a wall
    /// of diagnostics between the user and the thing they asked to look at.
    private func test(_ proofKind: Commitment.ProofKind) async {
        guard await AlarmService.shared.ensureAuthorized() else {
            testError = "Nagg needs alarm permission before it can ring. Allow it in Settings."
            return
        }
        do {
            testError = nil
            try await store.startRehearsal(proofKind: proofKind)
            onClose()
        } catch {
            testError = "Couldn't schedule the test: \(error.localizedDescription)"
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func commitmentRows(_ commitment: Commitment) -> some View {
        let chain = AlarmService.shared.chains[commitment.id]

        VStack(alignment: .leading, spacing: 4) {
            Text(commitment.isRehearsal ? "REHEARSAL" : commitment.title)
                .font(Nagg.sans(14, .medium))
                .foregroundStyle(Nagg.ink)

            // The number that matters most on this whole screen. Six is a healthy chain:
            // the ring plus five nags. One means the ring armed and every nag was refused,
            // which silently reduces the product to an ordinary alarm and shows nowhere
            // else in the app.
            row("alarms in chain", chain.map { "\($0.alarmIDs.count)" } ?? "no chain")
            row("proof kind", commitment.proofKind.rawValue)
            row("rings at", chain.map { Self.clock.string(from: $0.firstFire) } ?? "—")
            row("chain ends", chain.map { Self.clock.string(from: $0.expiresAt) } ?? "—")
            row("ringing now", store.needsProof(commitment) ? "YES" : "no")
            row("streak / misses", "\(commitment.currentStreak) / \(commitment.missCount)")
            row("days recorded", "\(commitment.provedDays?.count ?? 0) proved / \(commitment.missedDays?.count ?? 0) missed")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 10)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).naggLabel().padding(.bottom, 2)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Nagg.surface)
        .clipShape(.rect(cornerRadius: Nagg.radius))
        .overlay {
            RoundedRectangle(cornerRadius: Nagg.radius).stroke(Nagg.line, lineWidth: 1)
        }
        .padding(.bottom, 10)
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(Nagg.mono(11, .regular))
                .foregroundStyle(Nagg.ink3)
            Spacer(minLength: 12)
            Text(value)
                .font(Nagg.mono(11))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(value == "MISSING" || value == "denied" ? Nagg.alarm : Nagg.ink)
        }
    }

    // MARK: - Probes

    private var alarmStatus: String {
        switch AlarmManager.shared.authorizationState {
        case .authorized:    return "authorized"
        case .denied:        return "denied"
        case .notDetermined: return "not asked"
        @unknown default:    return "unknown"
        }
    }

    /// Actually builds a capture session rather than reporting what should happen. Every
    /// camera failure so far has been somewhere between "permission is granted" and "a
    /// preview appears", which is precisely the gap this closes.
    private func probe() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    cameraStatus = "authorized"
        case .denied:        cameraStatus = "denied"
        case .restricted:    cameraStatus = "restricted"
        case .notDetermined: cameraStatus = "not asked"
        @unknown default:    cameraStatus = "unknown"
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video) else {
            sessionStatus = "no camera device"
            return
        }
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            sessionStatus = "device found, input refused"
            return
        }

        let session = AVCaptureSession()
        let output = AVCapturePhotoOutput()
        session.beginConfiguration()
        let canInput = session.canAddInput(input)
        let canOutput = session.canAddOutput(output)
        session.commitConfiguration()

        sessionStatus = (canInput && canOutput) ? "ok" : "input:\(canInput) output:\(canOutput)"
    }

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM HH:mm:ss"
        return formatter
    }()
}
