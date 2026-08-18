import AudioToolbox
import AVFoundation
import SwiftUI
import UIKit

// `CameraPicker` used to live here: a `UIImagePickerController` presented as a sheet from
// inside the proof sheet. On device the camera never appeared — several builds, no crash,
// nothing in the log. It is gone rather than left around, because a type called
// CameraPicker sitting in a file called CaptureViews is an invitation to wire it back in.
// The camera is embedded now; see `CameraCaptureView`.

/// Carries an `AVCaptureSession` into a detached task.
///
/// The session is thread-safe by contract but Apple has not marked it `Sendable`, so a
/// closure that captures one cannot be passed where `sending` is required. Boxing states
/// the guarantee in one place instead of scattering `nonisolated(unsafe)` around, and
/// gives the next person somewhere to read why it is safe.
private final class SessionBox: @unchecked Sendable {
    let session = AVCaptureSession()
}

/// QR scanner for the desk-sticker proof mode.
///
/// The sticker is the commitment's UUID rendered as a QR code — see `DeskCodeView`, which
/// generates and prints it. Physically having to reach the desk is the entire point of
/// this proof mode, and the reason it is the hardest of the three.
struct QRScannerView: UIViewControllerRepresentable {

    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ controller: ScannerViewController, context: Context) {}

    /// `@preconcurrency` on the conformance, not a shortcut: `UIViewController` is
    /// `@MainActor` while `AVCaptureMetadataOutputObjectsDelegate` predates isolation,
    /// so Swift 6 cannot prove the callback arrives on the main actor. We prove it by
    /// construction — `setMetadataObjectsDelegate(self, queue: .main)` below. If that
    /// queue ever changes, this attribute becomes a lie and has to go with it.
    final class ScannerViewController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {

        var onScan: ((String) -> Void)?

        /// `nonisolated(unsafe)` because this is a property of a `@MainActor` view
        /// controller but `startRunning()` must not run on the main thread — it blocks.
        /// AVCaptureSession is documented as safe to drive from another thread, and we
        /// touch it in exactly three places: configure, start, stop.
        private let box = SessionBox()
        private var session: AVCaptureSession { box.session }
        private var previewLayer: AVCaptureVideoPreviewLayer?
        /// One scan per presentation. Without this the delegate fires every frame and
        /// the proof gets recorded dozens of times.
        private var hasScanned = false

        override func viewDidLoad() {
            super.viewDidLoad()
            configureSession()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard !session.isRunning else { return }
            // startRunning() blocks for a few hundred milliseconds, so it must not run
            // on the main thread. The box is what makes that legal — see SessionBox.
            Task.detached { [box] in box.session.startRunning() }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            session.stopRunning()
        }

        private func configureSession() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }

            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(layer)
            previewLayer = layer
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !hasScanned,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue else { return }

            hasScanned = true
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            onScan?(value)
        }
    }
}
