import SwiftUI

/// Creating a commitment is the point of highest intent in the app. Three fields,
/// one screen, no navigation stack. Ask for AlarmKit permission here — not on launch.
///
/// Styled as the prototype's sheet rather than a `Form`: uppercase micro-labels, inputs
/// drawn on `surface` with a hairline, and the two actions parked at the bottom where a
/// thumb is. A `Form` would have been less code and would have looked like Settings.
struct NewCommitmentView: View {

    /// Passed in, never read from the environment. `@Environment(Type.self)` on a
    /// non-optional traps at runtime when the value is absent, and this app has now lost
    /// three rounds to crashes that all looked identical from a phone with no debugger.
    /// A parameter cannot be missing, and the call site has to say what it depends on.
    let store: CommitmentStore
    let alarms: AlarmService
    /// Non-nil when editing rather than creating.
    ///
    /// Without this the only way to change a time was delete and re-add, which threw away
    /// the streak — quietly destroying the one thing the user has been accumulating, as a
    /// side effect of fixing a typo. In a habit app that is not a missing feature, it is a
    /// hole. Editing keeps the id, so the streak, the misses and the history all survive.
    var editing: Commitment? = nil
    /// Non-nil when a commitment was created. The caller decides what happens next —
    /// notably, a desk-code commitment needs its sticker shown, and presenting that from
    /// in here would be a sheet opened from inside a sheet, which is the exact shape that
    /// silently failed for the camera.
    let onFinish: (Commitment?) -> Void

    @State private var title = ""
    @State private var fireDate = Date()
    @State private var weekdays: Set<Int> = []
    @State private var proofKind: Commitment.ProofKind = .photo
    @State private var loaded = false
    @State private var permissionDenied = false
    @State private var scheduleError: String?

    /// Index 0 is Sunday, matching `Calendar.component(.weekday:)`.
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(editing == nil ? "New commitment" : "Edit commitment")
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

                if let scheduleError {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("The alarm didn't get set").naggLabel(Nagg.alarm)
                        Text(scheduleError)
                            .font(Nagg.sans(13))
                            .lineSpacing(3)
                            .foregroundStyle(Nagg.ink2)
                        Text("Nothing was saved. Try again — if it keeps failing, long-press the Nagg wordmark for diagnostics.")
                            .font(Nagg.sans(12))
                            .foregroundStyle(Nagg.ink3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Nagg.surface)
                    .clipShape(.rect(cornerRadius: Nagg.radius))
                    .overlay {
                        RoundedRectangle(cornerRadius: Nagg.radius).stroke(Nagg.alarm, lineWidth: 1)
                    }
                    .padding(.top, 18)
                }

                VStack(spacing: 9) {
                    Button(editing == nil ? "Lock it in" : "Save changes", action: save)
                        .buttonStyle(NaggPrimaryButton())
                        .disabled(!isValid)
                        .opacity(isValid ? 1 : 0.4)

                    Button("Never mind") { onFinish(nil) }
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
        // Fill in once. `onAppear` can run again on a re-render, and doing this twice
        // would stamp on whatever the user had already typed.
        .onAppear {
            guard !loaded, let editing else { loaded = true; return }
            title = editing.title
            fireDate = editing.fireDate
            weekdays = editing.repeats.weekdays
            proofKind = editing.proofKind
            loaded = true
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
            // Editing keeps the id and every counter hanging off it. Building a fresh
            // Commitment here would silently reset the streak, which is exactly the bug
            // this screen exists to stop.
            var commitment = editing ?? Commitment(
                title: title.trimmingCharacters(in: .whitespaces),
                fireDate: fireDate,
                repeats: Commitment.Repeat(weekdays: weekdays),
                proofKind: proofKind
            )
            commitment.title = title.trimmingCharacters(in: .whitespaces)
            commitment.fireDate = fireDate
            commitment.repeats = Commitment.Repeat(weekdays: weekdays)
            commitment.proofKind = proofKind
            // Not `try?`. If the alarm does not arm, the commitment is a row that never
            // rings — the failure this whole app is one long argument against, and the
            // one the user has no way of noticing until the morning it does not wake
            // them. `AlarmService` calls it "the worst bug this app can ship" and then
            // this call site used to swallow it.
            do {
                if editing == nil {
                    try await store.add(commitment)
                } else {
                    try await store.update(commitment)
                }
            } catch {
                scheduleError = error.localizedDescription
                return
            }

            onFinish(commitment)
        }
    }
}
