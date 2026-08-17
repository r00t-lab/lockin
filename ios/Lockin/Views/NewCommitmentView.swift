import SwiftUI

/// Creating a commitment is the point of highest intent in the app. Three fields,
/// one screen, no navigation stack. Ask for AlarmKit permission here — not on launch.
struct NewCommitmentView: View {

    @Environment(CommitmentStore.self) private var store
    @Environment(AlarmService.self) private var alarms
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var fireDate = Date()
    @State private var weekdays: Set<Int> = []
    @State private var proofKind: Commitment.ProofKind = .photo
    @State private var permissionDenied = false

    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            Form {
                Section("What are you starting?") {
                    TextField("Write the essay intro", text: $title)
                        .font(.title3)
                }

                Section("When") {
                    DatePicker("Time", selection: $fireDate, displayedComponents: .hourAndMinute)
                    weekdayPicker
                }

                Section("How you'll prove it") {
                    Picker("Proof", selection: $proofKind) {
                        ForEach(Commitment.ProofKind.allCases, id: \.self) { kind in
                            Label(kind.label, systemImage: kind.systemImageName).tag(kind)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if permissionDenied {
                    Section {
                        Text("Lockin needs alarm permission to ring through Silent and Focus. Without it this is just a reminder you'll swipe away.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                        Button("Open Settings") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .navigationTitle("New commitment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lock it in", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let isOn = weekdays.contains(day)
                Button(weekdaySymbols[day - 1]) {
                    if isOn { weekdays.remove(day) } else { weekdays.insert(day) }
                }
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(isOn ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isOn ? .white : .primary)
                .clipShape(.circle)
                .buttonStyle(.plain)
            }
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
            dismiss()
        }
    }
}
