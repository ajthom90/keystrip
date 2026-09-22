import Foundation
import Observation
import SwiftUI
import Synchronization
import UniformTypeIdentifiers
import KeystripCore

extension UTType {
    static let desiDatabase = UTType(importedAs: "com.desi.dsi", conformingTo: .database)
}

/// Everything needed to write the file, captured on the main thread.
struct DocumentSnapshot: Sendable {
    let current: DSIDocumentData
    let baseline: DSIDocumentData
    let original: Data
}

/// `data` is read by views and changed only by the `@MainActor` methods below.
/// SwiftUI may call `snapshot(contentType:)` off the main thread, so it reads a
/// Mutex-protected copy that every change refreshes. `original` and `baseline`
/// never change after init: each save applies all edits since opening to the
/// original bytes (spec section 4.4).
@Observable
final class KeystripDocument: ReferenceFileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.desiDatabase] }

    private(set) var data: DSIDocumentData
    @ObservationIgnored private let baseline: DSIDocumentData
    @ObservationIgnored private let original: Data
    @ObservationIgnored private let saveCopy: Mutex<DSIDocumentData>

    init() {
        let bytes = (try? DSIWriter.emptyDatabase()) ?? Data()
        let loaded = (try? DSIReader.read(bytes)) ?? DSIDocumentData()
        original = bytes
        baseline = loaded
        data = loaded
        saveCopy = Mutex(loaded)
    }

    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let loaded = try DSIReader.read(bytes)
        original = bytes
        baseline = loaded
        data = loaded
        saveCopy = Mutex(loaded)
    }

    func snapshot(contentType: UTType) throws -> DocumentSnapshot {
        DocumentSnapshot(current: saveCopy.withLock { $0 }, baseline: baseline, original: original)
    }

    func fileWrapper(snapshot: DocumentSnapshot, configuration: WriteConfiguration) throws -> FileWrapper {
        let bytes = try DSIWriter.write(snapshot.current, previous: snapshot.baseline, original: snapshot.original)
        return FileWrapper(regularFileWithContents: bytes)
    }

    // MARK: - Changes (main actor only)

    /// Selection is saved with the next real save but is not undoable and doesn't dirty the document.
    @MainActor func select(_ id: String?) {
        guard data.selectedPhoneID != id else { return }
        data.selectedPhoneID = id
        publish()
    }

    /// Applies `change`; if it altered anything, registers an undo that restores the previous state.
    @MainActor @discardableResult
    func edit<T>(_ actionName: String, undoManager: UndoManager?, _ change: (inout DSIDocumentData) throws -> T) throws -> T {
        var working = data
        let result = try change(&working)
        guard working != data else { return result }
        let before = data
        data = working
        publish()
        registerUndo(restoring: before, actionName: actionName, undoManager: undoManager)
        return result
    }

    @MainActor private func registerUndo(restoring previous: DSIDocumentData, actionName: String, undoManager: UndoManager?) {
        guard let undoManager else { return }
        let current = data
        undoManager.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.data = previous
                document.publish()
                document.registerUndo(restoring: current, actionName: actionName, undoManager: undoManager)
            }
        }
        undoManager.setActionName(actionName)
    }

    @MainActor private func publish() {
        let copy = data
        saveCopy.withLock { $0 = copy }
    }
}

// MARK: - Edit conveniences

extension KeystripDocument {
    @MainActor @discardableResult
    func addPhone(id: String, name: String, typecode: String, copyingFrom sourceID: String?, includeNameStrip: Bool, undoManager: UndoManager?) throws -> String {
        try edit("New Phone", undoManager: undoManager) { data in
            let newID = try data.addPhone(id: id, name: name, typecode: typecode, copyingFrom: sourceID, includeNameStrip: includeNameStrip)
            data.selectedPhoneID = newID
            return newID
        }
    }

    @MainActor func deletePhone(id: String, undoManager: UndoManager?) throws {
        try edit("Delete Phone", undoManager: undoManager) { try $0.deletePhone(id: id) }
    }

    @MainActor @discardableResult
    func renamePhone(id: String, to newID: String, undoManager: UndoManager?) throws -> String {
        try edit("Change Phone ID", undoManager: undoManager) { try $0.renamePhone(id: id, to: newID) }
    }

    @MainActor func setName(_ name: String, phoneID: String, undoManager: UndoManager?) {
        try? edit("Change Name", undoManager: undoManager) { try $0.setName(name, phoneID: phoneID) }
    }

    @MainActor func setTypecode(_ typecode: String, phoneID: String, undoManager: UndoManager?) {
        try? edit("Change Model", undoManager: undoManager) { try $0.setTypecode(typecode, phoneID: phoneID) }
    }

    @MainActor func setLabelText(_ text: String, phoneID: String, fieldID: Int, undoManager: UndoManager?) {
        try? edit("Typing", undoManager: undoManager) { try $0.setLabelText(text, phoneID: phoneID, fieldID: fieldID) }
    }

    @MainActor func updateLabelFormat(phoneID: String, fieldID: Int, undoManager: UndoManager?, _ change: (inout LabelFormat) -> Void) {
        try? edit("Format", undoManager: undoManager) { try $0.updateLabelFormat(phoneID: phoneID, fieldID: fieldID, change) }
    }
}
