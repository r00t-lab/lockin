import AVFoundation
import SwiftUI
import Vision

/// The moment the whole product exists for: the user has to demonstrate they started.
///
/// Design rule — this screen must be finishable in under 8 seconds. Every extra tap is
/// a person going back to bed. No settings, no explanations, one action.
struct ProofView: View {

    let commitment: Commitment

    @Environment(CommitmentStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var capturedImage: UIImage?
    @State private var isCheckingPhoto = false
    @State private var rejection: String?
    @State private var timerRemaining: TimeInterval = 25 * 60
    @State private var timerRunning = false
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                header

                switch commitment.proofKind {
                case .photo:      photoProof
                case .focusTimer: timerProof
                case .deskCode:   deskCodeProof
                }

                Spacer()

                if let rejection {
                    Text(rejection)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button("I'm not doing it", role: .destructive) {
                    Task {
                        await store.recordDismissal(for: commitment.id)
                        dismiss()
                    }
                }
                .font(.footnote)
            }
            .padding()
            .navigationBarBackButtonHidden()
            .interactiveDismissDisabled()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("YOU SAID YOU'D START")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.secondary)
            Text(commitment.title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            if commitment.currentStreak > 0 {
                Text("\(commitment.currentStreak) day streak on the line")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Photo

    private var photoProof: some View {
        VStack(spacing: 16) {
            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(.rect(cornerRadius: 16))
            }

            Button {
                showCamera = true
            } label: {
                Label(
                    capturedImage == nil ? "Photograph your setup" : "Retake",
                    systemImage: "camera.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isCheckingPhoto)

            if isCheckingPhoto {
                ProgressView("Checking…")
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(image: $capturedImage)
        }
        .onChange(of: capturedImage) { _, image in
            guard let image else { return }
            Task { await validate(image) }
        }
    }

    /// On-device first. A rectangle detection pass catches the obvious cheat — a photo
    /// of the ceiling, or of nothing — without a network round trip or an API bill.
    /// Only ambiguous frames should ever reach a server model.
    private func validate(_ image: UIImage) async {
        isCheckingPhoto = true
        rejection = nil
        defer { isCheckingPhoto = false }

        guard let cgImage = image.cgImage else { return }

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumObservations = 8
        request.minimumConfidence = 0.6

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try? handler.perform([request])

        let looksLikeAWorkspace = (request.results?.isEmpty == false)

        if looksLikeAWorkspace {
            await store.recordProof(for: commitment.id)
            dismiss()
        } else {
            rejection = "That doesn't look like a desk. Point it at what you're about to work on."
            capturedImage = nil
        }
    }

    // MARK: - Focus timer

    private var timerProof: some View {
        VStack(spacing: 20) {
            Text(timerRemaining.formattedClock)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            Button(timerRunning ? "Running" : "Start 25 minutes") {
                timerRunning = true
                Task {
                    // Starting is the proof. Finishing is between them and their degree.
                    await store.recordProof(for: commitment.id)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(timerRunning)
        }
        .task(id: timerRunning) {
            guard timerRunning else { return }
            while timerRemaining > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                timerRemaining -= 1
            }
            dismiss()
        }
    }

    // MARK: - Desk code

    private var deskCodeProof: some View {
        VStack(spacing: 16) {
            Text("Scan the sticker on your desk")
                .font(.headline)
            QRScannerView { payload in
                guard payload == commitment.id.uuidString else {
                    rejection = "Wrong code. That's not your desk."
                    return
                }
                Task {
                    await store.recordProof(for: commitment.id)
                    dismiss()
                }
            }
            .frame(height: 300)
            .clipShape(.rect(cornerRadius: 16))
        }
    }
}

private extension TimeInterval {
    var formattedClock: String {
        let total = Int(self)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
