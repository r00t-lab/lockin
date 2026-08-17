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
///
/// ## This is the screenshot
/// For most people the first and only Nagg surface they ever see is this one, on a locked
/// phone at 7am — and it is what a screen recording captures. So it gets the alarm red
/// full bleed and the app's own type, not the default dark Live Activity chrome with a
/// tinted padlock. `activityBackgroundTint` is what makes the whole card red; without it
/// the system picks its own material and the brand disappears.
struct LockinAlarmActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<LockinMetadata>.self) { context in
            lockScreenView(context.attributes.metadata)
                .padding(16)
                .activityBackgroundTint(Nagg.alarm)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("NAGG")
                        .font(Nagg.mono(11))
                        .tracking(1.4)
                        .foregroundStyle(Nagg.alarm)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.metadata?.title ?? fallbackTitle)
                        .font(Nagg.sans(16, .medium))
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
                            Text("I'm starting")
                                .font(Nagg.sans(15, .semibold))
                                .foregroundStyle(Nagg.alarmDeep)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(.white)
                                .clipShape(.rect(cornerRadius: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } compactLeading: {
                Circle().fill(Nagg.alarm).frame(width: 8, height: 8)
            } compactTrailing: {
                Text("NOW")
                    .font(Nagg.mono(11))
                    .tracking(0.6)
                    .foregroundStyle(Nagg.alarm)
            } minimal: {
                Circle().fill(Nagg.alarm).frame(width: 8, height: 8)
            }
        }
    }

    /// AlarmKit hands metadata across as an Optional — it can be absent if the alarm
    /// was restored without ours, or created outside the app. Treat that as a real
    /// state rather than force-unwrapping: the alarm still has to ring, it just
    /// cannot name the commitment.
    @ViewBuilder
    private func lockScreenView(_ metadata: LockinMetadata?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("You said you'd start")
                .font(Nagg.mono(11))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Nagg.alarmPale)

            Text(metadata?.title ?? fallbackTitle)
                .font(Nagg.sans(22, .medium))
                .foregroundStyle(.white)
                .lineLimit(3)

            if let metadata {
                Button(intent: ProofIntent(commitmentID: metadata.commitmentID.uuidString)) {
                    Text("I'm starting")
                        .font(Nagg.sans(15, .semibold))
                        .foregroundStyle(Nagg.alarmDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.white)
                        .clipShape(.rect(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fallbackTitle: String { "Time to start" }
}
