import AVFoundation
import CoreImage
import SwiftUI
import Vision

/// The moment the whole product exists for: the user has to demonstrate they started.
///
/// Design rule — this screen must be finishable in under 8 seconds. Every extra tap is
/// a person going back to bed. No settings, no explanations, one action.
///
/// Visually it is the calm after the red: same paper ground as the rest of the app, one
/// filled button, and the way out kept deliberately quiet at the bottom. The alarm screen
/// shouts; this one must not, or the user is still being shouted at while trying to comply.
struct ProofView: View {

    let commitment: Commitment
    /// Passed in, not read from the environment. `@Environment(Type.self)` on a
    /// non-optional traps at runtime when the value is missing, and on a phone with no
    /// debugger that crash is indistinguishable from every other one this screen has had.
    let store: CommitmentStore
    /// Called when this screen is finished with, instead of `@Environment(\.dismiss)` —
    /// proof is a state of the root view now, not a presentation.
    let onFinish: () -> Void

    @State private var capturedImage: UIImage?
    @State private var isCheckingPhoto = false
    @State private var rejection: String?
    @State private var timerRemaining: TimeInterval = 25 * 60
    @State private var timerRunning = false
    /// Earned the moment the timer starts, shown when the user is done watching it.
    @State private var timerProvedStreak: Int?
    /// Incremented to fire the shutter. A counter, not a flag — see `CameraCaptureView`.
    @State private var shutterTrigger = 0
    @State private var cameraDenied = false
    /// The streak to show on the payoff screen, set the moment proof lands.
    @State private var provenStreak: Int?

    var body: some View {
        ZStack {
            if let provenStreak {
                // The payoff.
                //
                // Not decoration. `CONTENT.md` lists "a celebration beat at the end" as
                // one of the five things every video in this category has in common, and
                // until now the app had none — proof landed and the screen simply closed,
                // which is a video with no last second. It is also the only moment Nagg
                // ever gives anything back, in an app whose entire job is to be
                // unpleasant at 7am.
                proofAccepted(streak: provenStreak)
            } else {
                proving
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .naggGround()
    }

    private var proving: some View {
        VStack(spacing: 0) {
            header

            switch commitment.proofKind {
            case .photo:      photoProof
            case .focusTimer: timerProof
            case .deskCode:   deskCodeProof
            }

            Spacer(minLength: 16)

            if let rejection {
                Text(rejection)
                    .font(Nagg.sans(13))
                    .lineSpacing(3)
                    .foregroundStyle(Nagg.alarm)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 6)
            }

            // Gone once the timer is running. Proof has already landed by then, and a
            // button that records an excuse against a day the user showed up is worse
            // than no button: it is the app calling them a liar for staying on screen.
            if !timerRunning {
                Button("I'm not doing it") {
                    Task {
                        await store.recordDismissal(for: commitment.id)
                        onFinish()
                    }
                }
                .buttonStyle(NaggBailButton())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Full bleed, one number, no buttons. It dismisses itself — a tap-to-continue would
    /// put a decision in front of someone who has just earned the opposite.
    private func proofAccepted(streak: Int) -> some View {
        VStack(spacing: 14) {
            Spacer()

            Text(streak > 0 ? "\(streak)" : "done")
                .font(Nagg.mono(96))
                .monospacedDigit()
                .tracking(-4)
                .foregroundStyle(Nagg.go)
                .contentTransition(.numericText())

            Text(payoffLine(streak))
                .font(Nagg.sans(16))
                .multilineTextAlignment(.center)
                .foregroundStyle(Nagg.ink2)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // Long enough to read and to film, short enough that nobody has to dismiss it.
            try? await Task.sleep(for: .milliseconds(1900))
            onFinish()
        }
    }

    /// The copy does the work the number cannot. Day one has nothing to boast about yet,
    /// and a long run is worth naming as a run rather than as a total.
    private func payoffLine(_ streak: Int) -> String {
        switch streak {
        case 0:      return "Started. That was the whole point."
        case 1:      return "Day one. The alarm has nothing on you."
        case 2...6:  return "\(streak) days straight."
        default:     return "\(streak) days. Nagg has stopped arguing with you."
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("You said you'd start").naggLabel()

            Text(commitment.title)
                .font(Nagg.sans(28, .medium))
                .foregroundStyle(Nagg.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            if commitment.currentStreak > 0 {
                // The one number on this screen. It is the whole reason someone gets up.
                (Text("\(commitment.currentStreak)").font(Nagg.mono(13))
                    + Text(" day streak on the line").font(Nagg.sans(13)))
                    .foregroundStyle(Nagg.alarm)
            }
        }
        .padding(.bottom, 22)
    }

    // MARK: - Photo
    //
    // The camera lives on this screen rather than behind a button that presents one.
    // Presenting it as a sheet from inside a sheet did not work on device, across several
    // builds, with no crash and nothing in the log — see `CameraCaptureView`.

    private var photoProof: some View {
        VStack(spacing: 16) {
            ZStack {
                if let capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFill()
                } else if cameraDenied {
                    deniedNotice
                } else {
                    CameraCaptureView(shutterTrigger: shutterTrigger) { image in
                        capturedImage = image
                    }
                }
            }
            .frame(height: 260)
            .frame(maxWidth: .infinity)
            .background(Nagg.sunk)
            .clipShape(.rect(cornerRadius: Nagg.radius))

            if !cameraDenied {
                Button(capturedImage == nil ? "Take the photo" : "Retake") {
                    if capturedImage == nil {
                        shutterTrigger += 1
                    } else {
                        capturedImage = nil
                        rejection = nil
                    }
                }
                .buttonStyle(NaggPrimaryButton())
                .disabled(isCheckingPhoto)
            }

            if isCheckingPhoto {
                Text("Checking…").naggLabel()
            }
        }
        .task { await resolveCameraAccess() }
        .onChange(of: capturedImage) { _, image in
            guard let image else { return }
            Task { await validate(image) }
        }
    }

    private var deniedNotice: some View {
        VStack(spacing: 12) {
            Text("Nagg can't open the camera, so it can't take your proof. Allow camera access and this works again.")
                .font(Nagg.sans(14))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(Nagg.ink2)

            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(NaggGhostButton())
        }
        .padding(20)
    }

    /// Decide whether this photo counts.
    ///
    /// `PRODUCT.md` draws a red line here and the previous version crossed it: "a wrongly
    /// rejected photo is far worse than an accepted fake one — someone cheating has
    /// already paid". Requiring `VNDetectRectanglesRequest` to find something meant a
    /// cluttered desk, a dim room or an odd angle could refuse a person who genuinely got
    /// up, while an alarm carried on nagging them and the app offered no way out. That is
    /// the worst failure this screen has.
    ///
    /// So the test is inverted. Anything that looks like a real photograph passes. The
    /// only thing rejected is a frame with nothing in it — a covered lens, the inside of
    /// a duvet, a dark ceiling — which is the actual cheat and is unambiguous.
    private func validate(_ image: UIImage) async {
        isCheckingPhoto = true
        rejection = nil
        defer { isCheckingPhoto = false }

        guard let cgImage = image.cgImage else { return }

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.2
        request.maximumObservations = 8
        request.minimumConfidence = 0.4

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try? handler.perform([request])

        let sawSomething = (request.results?.isEmpty == false)
        let isBlank = image.looksBlank

        if sawSomething || !isBlank {
            Haptics.proved()
            await store.recordProof(for: commitment.id)
            provenStreak = store.commitment(id: commitment.id)?.currentStreak ?? 0
        } else {
            Haptics.rejected()
            rejection = "That frame is empty. Point the camera at what you're about to work on."
            capturedImage = nil
        }
    }

    // MARK: - Focus timer

    private var timerProof: some View {
        VStack(spacing: 22) {
            Text(timerRemaining.formattedClock)
                .font(Nagg.mono(58))
                .monospacedDigit()
                .tracking(-2)
                .contentTransition(.numericText())
                .foregroundStyle(timerRunning ? Nagg.go : Nagg.ink)

            Button(timerRunning ? "Running" : "Start 25 minutes") {
                timerRunning = true
                Haptics.proved()
                Task {
                    // Starting is the proof. Finishing is between them and their degree.
                    await store.recordProof(for: commitment.id)
                    timerProvedStreak = store.commitment(id: commitment.id)?.currentStreak ?? 0
                }
            }
            .buttonStyle(NaggPrimaryButton(tint: timerRunning ? Nagg.go : Nagg.ink))
            .disabled(timerRunning)

            // The clock was unreachable. Proof lands in milliseconds, the payoff screen
            // took over on the same tap, and the countdown was destroyed with the view
            // before a single second ticked — the one part of this proof the user can
            // actually watch, and nobody ever saw it. So the payoff waits now: until the
            // timer runs out, or until they say they are done.
            if timerRunning {
                VStack(spacing: 16) {
                    Text("The alarm is off. The next 25 minutes are yours.")
                        .font(Nagg.sans(14))
                        .foregroundStyle(Nagg.ink2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 24)

                    Button("Done") { provenStreak = timerProvedStreak ?? 0 }
                        .buttonStyle(NaggBailButton())
                }
            }
        }
        .padding(.top, 12)
        .animation(.easeOut(duration: 0.22), value: timerRunning)
        .task(id: timerRunning) {
            guard timerRunning else { return }
            while timerRemaining > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                timerRemaining -= 1
            }
            // Sat through the whole thing without being asked to. That earns the beat.
            if timerRemaining <= 0, !Task.isCancelled {
                provenStreak = timerProvedStreak ?? 0
            }
        }
    }

    // MARK: - Desk code

    private var deskCodeProof: some View {
        VStack(spacing: 14) {
            Text("Scan the sticker on your desk").naggLabel()

            // A denied camera used to render as a black rectangle with no explanation,
            // at the one moment the user most needs the app to be clear. Say what is
            // wrong and open the place that fixes it.
            if cameraDenied {
                VStack(spacing: 12) {
                    Text("Nagg can't open the camera, so it can't read your desk code. Allow camera access and this works again.")
                        .font(Nagg.sans(14))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Nagg.ink2)

                    Button("Open Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .buttonStyle(NaggGhostButton())
                }
                .padding(.vertical, 40)
            } else {
                QRScannerView { payload in
                    guard payload == commitment.id.uuidString else {
                        Haptics.rejected()
                        rejection = "Wrong code. That's not your desk."
                        return
                    }
                    Task {
                        Haptics.proved()
                        await store.recordProof(for: commitment.id)
                        provenStreak = store.commitment(id: commitment.id)?.currentStreak ?? 0
                    }
                }
                .frame(height: 300)
                .clipShape(.rect(cornerRadius: Nagg.radius))

                Text("Lost the sticker? Your code is on the commitment's card, behind the QR button.")
                    .font(Nagg.sans(12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Nagg.ink3)
            }
        }
        .task { await resolveCameraAccess() }
    }

    /// Ask once, here, rather than letting `AVCaptureSession` fail silently inside the
    /// scanner. `.notDetermined` has to be requested before the session is built or the
    /// first presentation always shows nothing.
    private func resolveCameraAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraDenied = false
        case .notDetermined:
            cameraDenied = !(await AVCaptureDevice.requestAccess(for: .video))
        default:
            cameraDenied = true
        }
    }
}

private extension UIImage {
    /// True when the frame carries essentially no image — a covered lens, the inside of a
    /// duvet, a dark ceiling.
    ///
    /// Averaged down to a single pixel by CoreImage rather than walked in Swift: this runs
    /// on a full-resolution photo while someone is standing at their desk waiting, and the
    /// GPU path is the difference between instant and a visible pause.
    var looksBlank: Bool {
        guard let cgImage else { return false }
        let input = CIImage(cgImage: cgImage)

        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [kCIInputImageKey: input, kCIInputExtentKey: CIVector(cgRect: input.extent)]
        ), let output = filter.outputImage else { return false }

        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        // Rec. 709 luma. The threshold is deliberately low — this is a floor for "there is
        // nothing here at all", not a judgement about lighting. A dim dorm room at 6am has
        // to pass, because that is the exact situation the app was built for.
        let luma = 0.2126 * Double(pixel[0]) + 0.7152 * Double(pixel[1]) + 0.0722 * Double(pixel[2])
        return luma < 12
    }
}

private extension TimeInterval {
    var formattedClock: String {
        let total = Int(self)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
