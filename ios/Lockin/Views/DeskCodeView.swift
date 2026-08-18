import CoreImage.CIFilterBuiltins
import SwiftUI

/// The desk sticker.
///
/// ## Why this screen has to exist
/// Without it, "Scan your desk code" is a trap. The user picks it, the alarm fires, the
/// proof screen opens a scanner that only accepts this commitment's UUID — and nothing
/// anywhere in the app has ever shown them that code. They cannot prove, cannot stop the
/// nagging, and the app looks broken in the exact moment it is supposed to be trusted.
/// Android has had the generator since day one; iOS shipped the scanner without it.
///
/// ## Why it is the hardest proof mode, deliberately
/// The payload is the commitment's UUID and nothing else — no URL, no JSON, no version
/// prefix. The scanner does a plain string comparison, so a code cannot be "nearly right"
/// and a screenshot of somebody else's sticker is worthless. Keep it that way.
///
/// Getting out of bed to scan a sticker on a desk is the whole mechanic. That means this
/// code has to survive being printed on a cheap inkjet, taped to a desk, and scanned in
/// bad light by someone who has just woken up — hence the high error correction and the
/// deliberately large quiet margin.
struct DeskCodeView: View {

    let commitment: Commitment

    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Your desk code").naggLabel().padding(.bottom, 10)

                Text(commitment.title)
                    .font(Nagg.sans(22, .medium))
                    .foregroundStyle(Nagg.ink)
                    .multilineTextAlignment(.center)

                code
                    .padding(.top, 24)

                Text("Print it, or screenshot it and prop the screen where you work. When the alarm goes off, the only way to stop it is to be close enough to scan this.")
                    .font(Nagg.sans(13))
                    .lineSpacing(4)
                    .foregroundStyle(Nagg.ink2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 22)
                    .padding(.horizontal, 8)

                VStack(spacing: 9) {
                    if let image = shareableImage {
                        ShareLink(item: image, preview: SharePreview("Nagg desk code", image: image)) {
                            Text("Save or print")
                        }
                        .buttonStyle(NaggPrimaryButton())
                    }

                    Button("Done") { dismiss() }
                        .buttonStyle(NaggGhostButton())
                }
                .padding(.top, 26)
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 24)
        }
        .naggGround()
    }

    /// Rendered on paper with a wide quiet zone. A QR code printed edge to edge is a QR
    /// code that scanners struggle with; the margin is part of the spec, not styling.
    private var code: some View {
        Group {
            if let cg = Self.qrImage(for: commitment.id.uuidString) {
                Image(decorative: cg, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Couldn't draw the code")
                    .font(Nagg.sans(13))
                    .foregroundStyle(Nagg.alarm)
            }
        }
        .frame(maxWidth: 260, maxHeight: 260)
        .padding(26)
        .background(Nagg.surface)
        .clipShape(.rect(cornerRadius: Nagg.radius))
        .overlay {
            RoundedRectangle(cornerRadius: Nagg.radius).stroke(Nagg.line, lineWidth: 1)
        }
    }

    @MainActor
    private var shareableImage: Image? {
        guard let cg = Self.qrImage(for: commitment.id.uuidString) else { return nil }
        return Image(decorative: cg, scale: 1)
    }

    // MARK: - Generation

    /// Error correction is `H` on purpose. This gets printed, taped down, and scanned in
    /// bad light; redundancy is cheaper than a failed proof at 7am.
    static func qrImage(for payload: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "H"

        guard let output = filter.outputImage else { return nil }

        // CoreImage emits roughly one pixel per module. Scale up with a plain transform
        // rather than letting SwiftUI resample it — `.interpolation(.none)` above keeps
        // the edges hard, which is what a scanner wants.
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }
}
