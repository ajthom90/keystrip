import KeystripCore
import SwiftUI

/// How a new-phone sheet was opened. Duplicate copies labels, including the name strip.
struct NewPhoneRequest: Identifiable {
    let id = UUID()
    var includeNameStrip: Bool
    var name: String
    var typecode: String
    /// Nil starts blank. A phone id copies that phone's labels.
    var sourcePhoneID: String?
}

/// ID, name, model, and an optional phone to copy labels from.
struct NewPhoneSheet: View {
    var document: KeystripDocument
    var request: NewPhoneRequest
    var undoManager: UndoManager?

    @Environment(\.dismiss) private var dismiss

    @State private var id: String
    @State private var name: String
    @State private var typecode: String
    @State private var sourcePhoneID: String?
    @State private var actionError: String?
    @State private var didCreate = false
    @FocusState private var idFocused: Bool

    init(document: KeystripDocument, request: NewPhoneRequest, undoManager: UndoManager?) {
        self.document = document
        self.request = request
        self.undoManager = undoManager
        _id = State(initialValue: "")
        _name = State(initialValue: request.name)
        _typecode = State(initialValue: request.typecode)
        _sourcePhoneID = State(initialValue: request.sourcePhoneID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Phone") {
                    TextField("ID", text: $id)
                        .focused($idFocused)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .onSubmit(create)
                    if let inlineError {
                        Text(inlineError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    TextField("Name", text: $name)
                    Picker("Model", selection: $typecode) {
                        ForEach(modelChoices) { model in
                            Text(model.displayName).tag(model.typecode)
                        }
                    }
                }
                Section {
                    Picker("Start from", selection: $sourcePhoneID) {
                        Text("Blank").tag(String?.none)
                        ForEach(startFromPhones) { phone in
                            Text(startFromLabel(phone)).tag(Optional(phone.id))
                        }
                    }
                }
            }
            .navigationTitle(request.includeNameStrip ? "Duplicate Phone" : "New Phone")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { dismiss() })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: create)
                        .disabled(idValidationError != nil)
                }
            }
            .onChange(of: id) { _, _ in actionError = nil }
            .onChange(of: sourcePhoneID) { _, _ in actionError = nil }
            .onAppear { idFocused = true }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 340)
        #endif
    }

    private var startFromPhones: [Phone] {
        PhoneSorting.sorted(document.data.phones, by: .id)
    }

    private var modelChoices: [PhoneModel] {
        guard PhoneCatalog.model(for: typecode) == nil else { return PhoneCatalog.known }
        return PhoneCatalog.known + [
            PhoneModel(
                typecode: typecode,
                displayName: PhoneCatalog.displayName(for: typecode),
                keyCount: 0
            ),
        ]
    }

    private var idValidationError: String? {
        do {
            _ = try document.data.validatedPhoneID(id)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private var inlineError: String? {
        idValidationError ?? actionError
    }

    private func startFromLabel(_ phone: Phone) -> String {
        phone.name.isEmpty ? phone.id : "\(phone.id) — \(phone.name)"
    }

    private func create() {
        guard !didCreate, idValidationError == nil else { return }
        do {
            try document.addPhone(
                id: id,
                name: name,
                typecode: typecode,
                copyingFrom: sourcePhoneID,
                includeNameStrip: sourcePhoneID != nil && request.includeNameStrip,
                undoManager: undoManager
            )
            didCreate = true
            dismiss()
        } catch {
            actionError = error.localizedDescription
        }
    }
}
