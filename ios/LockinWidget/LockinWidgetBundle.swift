import AlarmKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct LockinWidgetBundle: WidgetBundle {
    var body: some Widget {
        LockinAlarmActivity()
    }
}

/// The Lock Screen / Dynamic Island face of a firing commitment.
///
/// AlarmKit drives this for you — you do not start or stop the Live Activity yourself,
/// you just describe what it looks like for your metadata type. The generic parameter
/// must match the one used in `AlarmAttributes<LockinMetadata>` in the app target, and
/// `LockinMetadata.swift` must be a member of BOTH targets or this will not compile.
struct LockinAlarmActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<LockinMetadata>.self) { context in
            lockScreenView(context.attributes.metadata)
                .padding()
                .activityBackgroundTint(.black.opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.metadata?.title ?? fallbackTitle)
                        .font(.headline)
                        .lineLimit(2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // No metadata means we cannot say which commitment this is, so
                    // there is nothing honest to put behind the button. Show the ring
                    // without it rather than a control that leads nowhere.
                    if let metadata = context.attributes.metadata {
                        Button(intent: ProofIntent(
                            commitmentID: metadata.commitmentID.uuidString
                        )) {
                            Label("I'm starting", systemImage: "arrow.right.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } compactLeading: {
                Image(systemName: "lock.fill")
            } compactTrailing: {
                Text("NOW")
                    .font(.caption2.weight(.bold))
            } minimal: {
                Image(systemName: "lock.fill")
            }
        }
    }

    /// AlarmKit hands metadata across as an Optional — it can be absent if the alarm
    /// was restored without ours, or created outside the app. Treat that as a real
    /// state rather than force-unwrapping: the alarm still has to ring, it just
    /// cannot name the commitment.
    @ViewBuilder
    private func lockScreenView(_ metadata: LockinMetadata?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOU SAID YOU'D START")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.secondary)

            Text(metadata?.title ?? fallbackTitle)
                .font(.title3.weight(.bold))
                .lineLimit(2)

            if let metadata {
                Button(intent: ProofIntent(commitmentID: metadata.commitmentID.uuidString)) {
                    Label(metadata.proofKind.label, systemImage: metadata.proofKind.systemImageName)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var fallbackTitle: String { "Time to start" }
}
