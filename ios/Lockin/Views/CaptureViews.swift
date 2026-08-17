import AudioToolbox
import AVFoundation
import SwiftUI
import UIKit

/// System camera, no custom UI. The proof screen is time-critical; a bespoke capture
/// pipeline is exactly the kind of work that feels productive and ships nothing.
struct CameraPicker: UIViewControllerRepresentable {

    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.cameraDevice = .rear
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// QR scanner for the desk-sticker proof mode.
///
/// The sticker is just the commitment's UUID rendered as a QR code — generate it in
/// settings, let the user print or screenshot it. Cheap to build, and physically
/// getting to the desk is the entire point.
/// Carries an `AVCaptureSession` into a detached task.
///
/// The session is thread-safe by contract but Apple has not marked it `Sendable`, so a
/// closure that captures one cannot be passed where `sending` is required. Boxing states
/// the guarantee in one place instead of scattering `nonisolated(unsafe)` around, and
/// gives the next person somewhere to read why it is safe.
private final class SessionBox: @unchecked Sendable {
    let session = AVCaptureSession()
}

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
