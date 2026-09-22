import KeystripCore
import SwiftUI

struct ContentView: View {
    var document: KeystripDocument

    @Environment(\.undoManager) private var undoManager

    @State private var activeFieldID: Int?
    @State private var searchText = ""
    @State private var sortOrder: PhoneSortOrder = .id
    @State private var inspectorPresented = false
    @State private var phoneRequest: NewPhoneRequest?
    @State private var pendingDelete: Phone?
    @State private var confirmingDelete = false

    private static let minimumPointSize = 6.0
    private static let maximumPointSize = 24.0

    var body: some View {
        NavigationSplitView {
            PhoneListView(
                document: document,
                searchText: $searchText,
                sortOrder: $sortOrder,
                onNewPhone: beginNewPhone,
                onDuplicate: beginDuplicate,
                onDelete: requestDelete
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
        } detail: {
            detailColumn
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { inspectorPresented.toggle() }) {
                            Label("Toggle Inspector", systemImage: "sidebar.trailing")
                        }
                        .help("Toggle Inspector")
                        .accessibilityValue(inspectorPresented ? "Shown" : "Hidden")
                    }
                }
                .inspector(isPresented: $inspectorPresented) {
                    inspectorColumn
                }
        }
        .onChange(of: document.data.selectedPhoneID) { _, _ in
            activeFieldID = nil
        }
        .focusedSceneValue(\.editorActions, editorActions)
        .sheet(item: $phoneRequest) { request in
            NewPhoneSheet(document: document, request: request, undoManager: undoManager)
                .id(request.id)
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: $confirmingDelete,
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { phone in
            Button("Delete", role: .destructive) {
                performDelete(phone.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { phone in
            Text(deleteDialogMessage(for: phone))
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let phone = selectedPhone {
            PhoneEditorView(document: document, phone: phone, activeFieldID: $activeFieldID)
        } else {
            ContentUnavailableView(
                "No Phone Selected",
                systemImage: "phone",
                description: Text("Pick a phone from the list or add one.")
            )
        }
    }

    @ViewBuilder
    private var inspectorColumn: some View {
        Group {
            if let phone = selectedPhone {
                InspectorView(
                    document: document,
                    phone: phone,
                    activeFieldID: activeFieldID,
                    undoManager: undoManager
                )
            } else {
                ContentUnavailableView(
                    "No Phone Selected",
                    systemImage: "phone",
                    description: Text("Pick a phone to inspect it.")
                )
            }
        }
        .inspectorColumnWidth(min: 240, ideal: 280, max: 400)
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    private var selectedPhone: Phone? {
        guard let id = document.data.selectedPhoneID else { return nil }
        return document.data.phone(withID: id)
    }

    private var canEditLabel: Bool {
        guard let phone = selectedPhone, let fieldID = activeFieldID else { return false }
        return phone.fields[fieldID]?.isUnreadable != true
    }

    private var editorActions: EditorActions {
        EditorActions(
            canModifyPhone: selectedPhone != nil,
            canEditLabel: canEditLabel,
            newPhone: beginNewPhone,
            duplicatePhone: beginDuplicateSelected,
            deletePhone: deleteSelected,
            toggleBold: { updateFormat { $0.style.bold.toggle() } },
            toggleItalic: { updateFormat { $0.style.italic.toggle() } },
            toggleUnderline: { updateFormat { $0.style.underline.toggle() } },
            increaseFontSize: { adjustFontSize(by: 1) },
            decreaseFontSize: { adjustFontSize(by: -1) },
            alignLeft: { align(.left) },
            alignCenter: { align(.center) },
            alignRight: { align(.right) },
            toggleInspector: { inspectorPresented.toggle() }
        )
    }

    private var deleteDialogTitle: String {
        guard let phone = pendingDelete else { return "Delete Phone?" }
        return "Delete \"\(phone.id)\"?"
    }

    private func deleteDialogMessage(for phone: Phone) -> String {
        if phone.name.isEmpty {
            return "This phone will be removed from the database."
        }
        return "\"\(phone.name)\" will be removed from the database."
    }

    private func beginNewPhone() {
        phoneRequest = NewPhoneRequest(
            includeNameStrip: false,
            name: "",
            typecode: PhoneCatalog.defaultModel.typecode,
            sourcePhoneID: nil
        )
    }

    private func beginDuplicate(_ phone: Phone) {
        phoneRequest = NewPhoneRequest(
            includeNameStrip: true,
            name: phone.name,
            typecode: phone.typecode,
            sourcePhoneID: phone.id
        )
    }

    private func beginDuplicateSelected() {
        guard let phone = selectedPhone else { return }
        beginDuplicate(phone)
    }

    private func deleteSelected() {
        guard let phone = selectedPhone else { return }
        requestDelete(phone)
    }

    private func requestDelete(_ phone: Phone) {
        pendingDelete = phone
        confirmingDelete = true
    }

    private func performDelete(_ id: String) {
        let nextID = phoneIDToSelect(afterDeleting: id)
        do {
            try document.deletePhone(id: id, undoManager: undoManager)
            document.select(nextID)
        } catch {
            // The phone was already removed.
        }
    }

    /// The next row in the sidebar, or the previous row when the last visible phone is deleted.
    private func phoneIDToSelect(afterDeleting id: String) -> String? {
        let sorted = PhoneSorting.sorted(document.data.phones, by: sortOrder)
        let filtered = PhoneSorting.filter(sorted, matching: searchText)
        let ordered = filtered.contains(where: { $0.id == id }) ? filtered : sorted
        guard let index = ordered.firstIndex(where: { $0.id == id }) else {
            return document.data.selectedPhoneID == id ? nil : document.data.selectedPhoneID
        }
        if index + 1 < ordered.count {
            return ordered[index + 1].id
        }
        if index > 0 {
            return ordered[index - 1].id
        }
        return nil
    }

    private func updateFormat(_ change: (inout LabelFormat) -> Void) {
        guard canEditLabel, let phoneID = document.data.selectedPhoneID, let fieldID = activeFieldID else { return }
        document.updateLabelFormat(phoneID: phoneID, fieldID: fieldID, undoManager: undoManager, change)
    }

    private func adjustFontSize(by deltaPoints: Double) {
        updateFormat { format in
            let points = min(max(Double(format.fontSize) / 2 + deltaPoints, Self.minimumPointSize), Self.maximumPointSize)
            format.fontSize = Int((points * 2).rounded())
        }
    }

    private func align(_ alignment: LabelAlignment) {
        updateFormat { $0.alignment = alignment }
    }
}
