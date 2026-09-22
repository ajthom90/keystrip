import KeystripCore
import SwiftUI

/// Temporary split view that proves open, select, and save. Task 11 replaces it.
struct ContentView: View {
    var document: KeystripDocument

    var body: some View {
        NavigationSplitView {
            List(document.data.phones, selection: selection) { phone in
                VStack(alignment: .leading, spacing: 2) {
                    Text(phone.id)
                        .font(.headline)
                    Text(phone.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            .navigationTitle("Phones")
        } detail: {
            if let phone = selectedPhone {
                VStack(alignment: .leading, spacing: 8) {
                    Text(phone.id)
                        .font(.title)
                    Text(labelCount(phone.fields.count))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
            } else {
                ContentUnavailableView(
                    "No Phone Selected",
                    systemImage: "phone",
                    description: Text("Select a phone from the list.")
                )
            }
        }
    }

    /// List selection writes through `select`, which is not an undoable edit.
    private var selection: Binding<String?> {
        Binding(
            get: { document.data.selectedPhoneID },
            set: { document.select($0) }
        )
    }

    private var selectedPhone: Phone? {
        guard let id = document.data.selectedPhoneID else { return nil }
        return document.data.phones.first { $0.id == id }
    }

    private func labelCount(_ count: Int) -> String {
        count == 1 ? "1 label" : "\(count) labels"
    }
}
