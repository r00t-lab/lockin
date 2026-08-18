import SwiftUI

/// Creating a commitment is the point of highest intent in the app. Three fields,
/// one screen, no navigation stack. Ask for AlarmKit permission here — not on launch.
///
/// Styled as the prototype's sheet rather than a `Form`: uppercase micro-labels, inputs
/// drawn on `surface` with a hairline, and the two actions parked at the bottom where a
/// thumb is. A `Form` would have been less code and would have looked like Settings.
struct NewCommitmentView: View {

    @Environment(CommitmentStore.self) private var store
    @Environment(AlarmService.self) private var alarms
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var fireDate = Date()
    @State private var weekdays: Set<Int> = []
    @State private var proofKind: Commitment.ProofKind = .photo
    @State private var permissionDenied = false
    /// Set after saving a desk-code commitment so the sticker is shown immediately.
    @State private var createdDeskCode: Commitment?

    /// Index 0 is Sunday, matching `Calendar.component(.weekday:)`.
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("New commitment")
                    .font(Nagg.sans(20, .medium))
                    .foregroundStyle(Nagg.ink)
                    .padding(.bottom, 20)

                Text("What are you starting").naggLabel().padding(.bottom, 7)
                TextField("Write the essay intro", text: $title)
                    .font(Nagg.sans(16))
                    .foregroundStyle(Nagg.ink)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Nagg.surface)
                    .clipShape(.rect(cornerRadius: 11))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11).stroke(Nagg.line, lineWidth: 1)
                    }

                Text("Time").naggLabel().padding(.top, 16).padding(.bottom, 7)
                DatePicker("", selection: $fireDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Nagg.ink)

                Text("Repeat").naggLabel().padding(.top, 16).padding(.bottom, 7)
                weekdayPicker

                Text("How you'll prove it").naggLabel().padding(.top, 16).padding(.bottom, 7)
                VStack(spacing: 8) {
                    ForEach(Commitment.ProofKind.allCases, id: \.self) { kind in
                        proofOption(kind)
                    }
                }

                if permissionDenied { permissionNotice.padding(.top, 18) }

                VStack(spacing: 9) {
                    Button("Lock it in", action: save)
                        .buttonStyle(NaggPrimaryButton())
                        .disabled(!isValid)
                        .opacity(isValid ? 1 : 0.4)

                    Button("Never mind") { dismiss() }
                        .buttonStyle(NaggGhostButton())
                }
                .padding(.top, 26)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .naggGround()
        .scrollDismissesKeyboard(.interactively)
        // Show the sticker the moment a desk-code commitment is created. Anyone who has
        // to go hunting for it later has already been locked out of their own alarm once.
        .sheet(item: $createdDeskCode, onDismiss: { dismiss() }) { commitment in
            DeskCodeView(commitment: commitment)
        }
    }

    // MARK: - Pieces

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let isOn = weekdays.contains(day)
                Button {
                    if isOn { weekdays.remove(day) } else { weekdays.insert(day) }
                } label: {
                    Text(weekdaySymbols[day - 1])
                        .font(Nagg.mono(13, .medium))
                        .foregroundStyle(isOn ? Nagg.ground : Nagg.ink2)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(isOn ? Nagg.ink : Nagg.surface)
                        .clipShape(.circle)
                        .overlay { Circle().stroke(isOn ? .clear : Nagg.line, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private func proofOption(_ kind: Commitment.ProofKind) -> some View {
        let isOn = proofKind == kind
        return Button {
            proofKind = kind
        } label: {
            HStack(spacing: 12) {
                Image(systemName: kind.systemImageName)
                    .font(.system(size: 15))
                    .frame(width: 22)
                Text(kind.label)
                    .font(Nagg.sans(15))
                Spacer()
            }
            .foregroundStyle(isOn ? Nagg.ground : Nagg.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(isOn ? Nagg.ink : Nagg.surface)
            .clipShape(.rect(cornerRadius: 11))
            .overlay {
                RoundedRectangle(cornerRadius: 11).stroke(isOn ? .clear : Nagg.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var permissionNotice: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nagg needs alarm permission to ring through Silent and Focus. Without it this is just a reminder you'll swipe away.")
                .font(Nagg.sans(13))
                .lineSpacing(3)
                .foregroundStyle(Nagg.alarm)

            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(NaggGhostButton(tint: Nagg.alarm))
        }
        .padding(14)
        .background(Nagg.surface)
        .clipShape(.rect(cornerRadius: Nagg.radius))
        .overlay {
            RoundedRectangle(cornerRadius: Nagg.radius).stroke(Nagg.alarm, lineWidth: 1)
        }
    }

    private func save() {
        Task {
            guard await alarms.ensureAuthorized() else {
                permissionDenied = true
                return
            }
            let commitment = Commitment(
                title: title.trimmingCharacters(in: .whitespaces),
                fireDate: fireDate,
                repeats: Commitment.Repeat(weekdays: weekdays),
                proofKind: proofKind
            )
            try? await store.add(commitment)

            if proofKind == .deskCode {
                createdDeskCode = commitment
            } else {
                dismiss()
            }
        }
    }
}
