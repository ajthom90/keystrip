import KeystripCore
import SwiftUI

/// Sidebar list of phones, with search and sort.
struct PhoneListView: View {
    var document: KeystripDocument

    @State private var searchText = ""
    @State private var sortOrder: PhoneSortOrder = .id

    var body: some View {
        Group {
            if document.data.phones.isEmpty {
                ContentUnavailableView(
                    "No Phones",
                    systemImage: "phone",
                    description: Text("This database has no phones yet.")
                )
            } else if displayedPhones.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(displayedPhones, selection: selection) { phone in
                    row(for: phone)
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle("Phones")
        .searchable(text: $searchText, prompt: "Search phones")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("Sort Order", selection: $sortOrder) {
                        Text("ID").tag(PhoneSortOrder.id)
                        Text("Name").tag(PhoneSortOrder.name)
                    }
                } label: {
                    Label("Sort Order", systemImage: "arrow.up.arrow.down")
                }
                .help("Sort Order")
            }
        }
    }

    private var displayedPhones: [Phone] {
        PhoneSorting.sorted(
            PhoneSorting.filter(document.data.phones, matching: searchText),
            by: sortOrder
        )
    }

    /// List selection writes through `select`, which is not an undoable edit.
    private var selection: Binding<String?> {
        Binding(
            get: { document.data.selectedPhoneID },
            set: { document.select($0) }
        )
    }

    private func row(for phone: Phone) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(phone.id)
                .font(.headline)
            Text(phone.name.isEmpty ? "No name" : phone.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(PhoneCatalog.displayName(for: phone.typecode))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }
}
