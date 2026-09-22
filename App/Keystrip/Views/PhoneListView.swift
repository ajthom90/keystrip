import KeystripCore
import SwiftUI

/// Sidebar list of phones, with search, sort, and phone actions.
struct PhoneListView: View {
    var document: KeystripDocument
    @Binding var searchText: String
    @Binding var sortOrder: PhoneSortOrder
    var onNewPhone: @MainActor () -> Void
    var onDuplicate: @MainActor (Phone) -> Void
    var onDelete: @MainActor (Phone) -> Void

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
                        .contextMenu {
                            Button("Duplicate") { onDuplicate(phone) }
                            Button("Delete", role: .destructive) { onDelete(phone) }
                        }
                }
                .listStyle(.sidebar)
                #if os(macOS)
                .onDeleteCommand(perform: deleteSelection)
                #endif
            }
        }
        .navigationTitle("Phones")
        .searchable(text: $searchText, prompt: "Search phones")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onNewPhone) {
                    Label("New Phone", systemImage: "plus")
                }
                .help("New Phone")
            }
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

    #if os(macOS)
    /// Delete key while a visible sidebar row is selected. Nil leaves the command disabled.
    private var deleteSelection: (() -> Void)? {
        guard let id = document.data.selectedPhoneID,
              let phone = displayedPhones.first(where: { $0.id == id })
        else { return nil }
        return { onDelete(phone) }
    }
    #endif

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
