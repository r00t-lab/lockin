import AVFoundation
import SwiftUI
import UIKit

/// A live camera preview embedded straight into the proof screen.
///
/// ## Why this replaced `UIImagePickerController`
/// The old flow presented a picker as a sheet, from inside `ProofView`, which is itself a
/// sheet. On device the camera simply did not appear — repeatedly, across several builds,
/// with no crash and nothing in the log. Sheet-from-sheet has bitten this project twice
/// already; the list screen had to collapse four stacked `.sheet` modifiers into one for
/// the same reason.
///
/// So the camera is no longer *presented* at all. It is embedded, exactly the way
/// `QRScannerView` is — and that one has always worked. Same `AVCaptureSession` shape,
/// same `SessionBox`, same `@preconcurrency` delegate. Nothing about this path can be
/// swallowed by a presentation that decides not to happen.
///
/// It is also better for the product. Proof has to be finishable in eight seconds by
/// someone who just got out of bed: the camera is already looking at the desk when the
/// screen appears, and there is one button.
///
/// ## Triggering the shutter from SwiftUI
/// `shutterTrigger` is a counter, not a flag. A `Bool` has to be set back to false by
/// somebody, and forgetting to reset it means the second photo never fires — the exact
/// class of bug this file exists to stop repeating.
struct CameraCaptureView: UIViewControllerRepresentable {

    /// Increment to take a photo.
    let shutterTrigger: Int
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> CaptureViewController {
        let controller = CaptureViewController()
        controller.onCapture = onCapture
        return controller
    }

    func updateUIViewController(_ controller: CaptureViewController, context: Context) {
        controller.onCapture = onCapture
        controller.captureIfNeeded(trigger: shutterTrigger)
    }

    /// `@preconcurrency` on the conformance for the same reason as `QRScannerView`:
    /// `UIViewController` is `@MainActor` while `AVCapturePhotoCaptureDelegate` predates
    /// isolation. We prove main-actor delivery by construction — the completion below
    /// hops explicitly — rather than asking the compiler to.
    final class CaptureViewController: UIViewController, @preconcurrency AVCapturePhotoCaptureDelegate {

        var onCapture: ((UIImage) -> Void)?

        private let box = CaptureSessionBox()
        private var session: AVCaptureSession { box.session }
        private let output = AVCapturePhotoOutput()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        /// The last trigger value acted on, so a SwiftUI re-render cannot fire the
        /// shutter a second time on its own.
        private var lastTrigger = 0
        private var isCapturing = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            configureSession()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard !session.isRunning else { return }
            // `startRunning()` blocks for a few hundred milliseconds and must not run on
            // the main thread. The box is what makes handing it across legal.
            Task.detached { [box] in box.session.startRunning() }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            session.stopRunning()
        }

        private func configureSession() {
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                    ?? AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input),
                  session.canAddOutput(output)
            else {
                session.commitConfiguration()
                NaggLog.proof.error("NAGG camera: could not configure a capture session")
                return
            }

            session.addInput(input)
            session.addOutput(output)
            session.commitConfiguration()

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(layer)
            previewLayer = layer

            NaggLog.proof.notice("NAGG camera: session configured")
        }

        func captureIfNeeded(trigger: Int) {
            guard trigger != lastTrigger, trigger > 0, !isCapturing else { return }
            lastTrigger = trigger

            guard session.isRunning else {
                NaggLog.proof.error("NAGG camera: shutter pressed while the session was not running")
                return
            }

            isCapturing = true
            NaggLog.proof.notice("NAGG camera: shutter")
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }

        func photoOutput(
            _ output: AVCapturePhotoOutput,
            didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            isCapturing = false

            if let error {
                NaggLog.proof.error("NAGG camera: capture failed \(error.localizedDescription, privacy: .public)")
                return
            }
            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                NaggLog.proof.error("NAGG camera: capture produced no image")
                return
            }

            NaggLog.proof.notice("NAGG camera: captured")
            onCapture?(image)
        }
    }
}

/// Carries an `AVCaptureSession` into a detached task.
///
/// The session is thread-safe by contract but Apple has not marked it `Sendable`, so a
/// closure capturing one cannot be passed where `sending` is required. Boxing states the
/// guarantee once instead of scattering `nonisolated(unsafe)` around.
private final class CaptureSessionBox: @unchecked Sendable {
    let session = AVCaptureSession()
}
