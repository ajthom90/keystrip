import Foundation
import Testing
@testable import KeystripCore

struct DSIWriterTests {
    // MARK: Helpers

    /// Every row of every table, as sorted strings, so rowid changes don't matter.
    static func rows(_ data: Data) throws -> [String: [String]] {
        let db = try SQLiteDatabase(data: data)
        var result: [String: [String]] = [:]
        for table in ["meta", "extension", "field", "selections", "graphics"] {
            result[table] = try db.query("SELECT * FROM \(table)").map { row in
                row.map { $0.stringValue ?? "NULL" }.joined(separator: " | ")
            }.sorted()
        }
        return result
    }

    static func expectHealthy(_ data: Data) throws {
        let db = try SQLiteDatabase(data: data)
        #expect(try db.query("PRAGMA integrity_check") == [[.text("ok")]])
        #expect(try db.query("PRAGMA encoding") == [[.text("UTF-16le")]])
        #expect(try db.query("PRAGMA page_size") == [[.integer(1024)]])
        #expect(try db.query("PRAGMA foreign_key_check").isEmpty)
    }

    static func fieldContent(_ data: Data, _ phoneID: String, _ fieldID: Int) throws -> String? {
        try SQLiteDatabase(data: data)
            .query("SELECT content FROM field WHERE extension_id=? AND field_id=?", [.text(phoneID), .integer(Int64(fieldID))])
            .first?.first?.stringValue
    }

    /// Rows present in `after` but not `before`, and the reverse.
    static func difference(_ before: Data, _ after: Data) throws -> (added: [String], removed: [String]) {
        let b = try rows(before), a = try rows(after)
        var added: [String] = [], removed: [String] = []
        for table in b.keys.sorted() {
            let bs = Set(b[table] ?? []), as_ = Set(a[table] ?? [])
            added += as_.subtracting(bs).sorted().map { "\(table): \($0)" }
            removed += bs.subtracting(as_).sorted().map { "\(table): \($0)" }
        }
        return (added, removed)
    }

    // MARK: Tests

    @Test func unchangedDocumentWritesIdenticalBytes() throws {
        let data = try Fixture.data()
        let doc = try DSIReader.read(data)
        #expect(try DSIWriter.write(doc, previous: doc, original: data) == data)
    }

    @Test func editingOneLabelChangesOnlyThatRow() throws {
        let data = try Fixture.data()
        let previous = try DSIReader.read(data)
        var current = previous
        let i = try #require(current.index(ofPhone: "101"))
        current.phones[i].fields[7096]!.text = current.phones[i].fields[7096]!.text.replacingText("Pat")

        let written = try DSIWriter.write(current, previous: previous, original: data)
        try Self.expectHealthy(written)
        #expect(try Self.fieldContent(written, "101", 7096) == Fixture.header + #"\b Pat}"#)
        let diff = try Self.difference(data, written)
        #expect(diff.added == ["field: 101 | 7096 | " + Fixture.header + #"\b Pat}"#])
        #expect(diff.removed == ["field: 101 | 7096 | " + Fixture.header + #"\b Sam}"#])
    }

    @Test func revertedEditLeavesTheFileUnchanged() throws {
        let data = try Fixture.data()
        let previous = try DSIReader.read(data)
        var current = previous
        let i = try #require(current.index(ofPhone: "102"))
        let odd = current.phones[i].fields[9096]!.text
        current.phones[i].fields[9096]!.text = odd.replacingText("changed")
        current.phones[i].fields[9096]!.text = odd
        let written = try DSIWriter.write(current, previous: previous, original: data)
        #expect(try Self.difference(data, written).added.isEmpty)
        #expect(try Self.fieldContent(written, "102", 9096) == #"{\rtf1\ansi\deff0{\fonttbl{\f0\fswiss Arial;}}\f0\fs18\qc\b Odd}"#)
    }

    @Test func updatingPhoneColumnsLeavesFieldsAlone() throws {
        let data = try Fixture.data()
        let previous = try DSIReader.read(data)
        var current = previous
        let i = try #require(current.index(ofPhone: "102"))
        current.phones[i].name = "Chris Ngo"
        current.phones[i].typecode = "AWX9224"
        current.phones[i].modified = "20260922T120000"

        let written = try DSIWriter.write(current, previous: previous, original: data)
        try Self.expectHealthy(written)
        let diff = try Self.difference(data, written)
        #expect(diff.added == ["extension: 102 | AWX9224 | Chris Ngo | 20260922T120000"])
        #expect(diff.removed == ["extension: 102 | AWX9212 | Chris Ng | 20250829T103509"])
        #expect(try Self.fieldContent(written, "102", 10096) == "not rtf at all")
    }

    @Test func addingAPhoneInsertsItsRowAndFields() throws {
        let data = try Fixture.data()
        let previous = try DSIReader.read(data)
        var current = previous
        current.phones.append(Phone(id: "500", typecode: "AWX9212", name: "New Person", modified: "20260922T120000", fields: [
            4796: PhoneLabel(text: LabelText.template(forFieldID: 4796).replacingText("New x500")),
            5096: PhoneLabel(rtf: Fixture.header + #"\b Page\par Phones}"#),
        ]))

        let written = try DSIWriter.write(current, previous: previous, original: data)
        try Self.expectHealthy(written)
        let diff = try Self.difference(data, written)
        #expect(diff.removed.isEmpty)
        #expect(diff.added == [
            "extension: 500 | AWX9212 | New Person | 20260922T120000",
            "field: 500 | 4796 | " + Fixture.header + " New x500}",
            "field: 500 | 5096 | " + Fixture.header + #"\b Page\par Phones}"#,
        ])
        let reread = try DSIReader.read(written)
        #expect(reread.phones.last?.id == "500")
    }

    @Test func deletingThePhoneAlsoRemovesItsFieldsAndSelection() throws {
        let data = try Fixture.data()
        let previous = try DSIReader.read(data)
        var current = previous
        current.phones.removeAll { $0.id == "102" }
        current.selectedPhoneID = nil

        let written = try DSIWriter.write(current, previous: previous, original: data)
        try Self.expectHealthy(written)
        let reread = try DSIReader.read(written)
        #expect(reread.phone(withID: "102") == nil)
        #expect(reread.selectedPhoneID == nil)
        let diff = try Self.difference(data, written)
        #expect(diff.added.isEmpty)
        #expect(diff.removed.count == 1 + 8 + 1)  // extension row, 8 fields, selection
        #expect(diff.removed.allSatisfy { $0.contains("102") })
    }

    @Test func renamingAPhoneMovesEveryFieldByteForByte() throws {
        let data = try Fixture.data()
        let previous = try DSIReader.read(data)
        var current = previous
        let i = try #require(current.index(ofPhone: "300"))
        current.phones[i].id = "301"

        let written = try DSIWriter.write(current, previous: previous, original: data)
        try Self.expectHealthy(written)
        let db = try SQLiteDatabase(data: written)
        #expect(try db.query("SELECT count(*) FROM field WHERE extension_id='300'") == [[.integer(0)]])
        #expect(try db.query("SELECT count(*) FROM field WHERE extension_id='301'") == [[.integer(4)]])
        let before = try SQLiteDatabase(data: data).query("SELECT field_id, content FROM field WHERE extension_id='300' ORDER BY field_id")
        let after = try db.query("SELECT field_id, content FROM field WHERE extension_id='301' ORDER BY field_id")
        #expect(before == after)
    }

    @Test func renamingTheSelectedPhoneMovesTheSelection() throws {
        let data = try Fixture.data()
        let previous = try DSIReader.read(data)
        var current = previous
        let i = try #require(current.index(ofPhone: "102"))
        current.phones[i].id = "103"
        current.selectedPhoneID = "103"
        let written = try DSIWriter.write(current, previous: previous, original: data)
        try Self.expectHealthy(written)
        #expect(try DSIReader.read(written).selectedPhoneID == "103")
    }

    @Test func clearingAndAddingFields() throws {
        let data = try Fixture.data()
        let previous = try DSIReader.read(data)
        var current = previous
        let i = try #require(current.index(ofPhone: "Template"))
        current.phones[i].fields[8096] = nil
        current.phones[i].fields[9096] = PhoneLabel(text: LabelText.template(forFieldID: 9096).replacingText("New"))

        let written = try DSIWriter.write(current, previous: previous, original: data)
        try Self.expectHealthy(written)
        #expect(try Self.fieldContent(written, "Template", 8096) == nil)
        #expect(try Self.fieldContent(written, "Template", 9096) == Fixture.header + #"\b New}"#)
    }

    @Test func changingTheSelectionRewritesSelections() throws {
        let data = try Fixture.data()
        let previous = try DSIReader.read(data)
        var current = previous
        current.selectedPhoneID = "240"
        let written = try DSIWriter.write(current, previous: previous, original: data)
        #expect(try SQLiteDatabase(data: written).query("SELECT extension_id FROM selections") == [[.text("240")]])

        current.selectedPhoneID = "missing"
        let ignored = try DSIWriter.write(current, previous: previous, original: data)
        #expect(try SQLiteDatabase(data: ignored).query("SELECT extension_id FROM selections") == [[.text("102")]])
    }

    @Test func unreadableAndOddLabelsSurviveNeighbouringEdits() throws {
        let data = try Fixture.data()
        let previous = try DSIReader.read(data)
        var current = previous
        let i = try #require(current.index(ofPhone: "102"))
        current.phones[i].fields[5096]!.text = current.phones[i].fields[5096]!.text.replacingText("Operator")
        let written = try DSIWriter.write(current, previous: previous, original: data)
        #expect(try Self.fieldContent(written, "102", 10096) == "not rtf at all")
        #expect(try Self.fieldContent(written, "102", 9096) == #"{\rtf1\ansi\deff0{\fonttbl{\f0\fswiss Arial;}}\f0\fs18\qc\b Odd}"#)
        #expect(try Self.fieldContent(written, "102", 5096) == #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green64\blue64;}\f0\cf0\fs18\qc\b Operator}"#)
    }

    @Test func duplicatePhoneIDsAreRejected() throws {
        let data = try Fixture.data()
        let previous = try DSIReader.read(data)
        var current = previous
        current.phones.append(current.phones[0])
        #expect(throws: DSIError.duplicatePhoneID("101")) {
            try DSIWriter.write(current, previous: previous, original: data)
        }
    }

    @Test func emptyDatabaseMatchesDESIsSchema() throws {
        let data = try DSIWriter.emptyDatabase()
        try Self.expectHealthy(data)
        let db = try SQLiteDatabase(data: data)
        let sql = try db.query("SELECT sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY rowid").compactMap { $0.first?.stringValue }
        #expect(sql == [
            "CREATE TABLE meta (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL DEFAULT (''))",
            "CREATE TABLE extension (id TEXT NOT NULL PRIMARY KEY, typecode TEXT NOT NULL, name TEXT NOT NULL DEFAULT (''), modified TEXT NOT NULL)",
            "CREATE TABLE field (extension_id TEXT NOT NULL REFERENCES extension(id) ON UPDATE CASCADE ON DELETE CASCADE, field_id INTEGER NOT NULL, content TEXT NOT NULL DEFAULT (''), PRIMARY KEY (extension_id, field_id))",
            "CREATE TABLE selections (extension_id TEXT NOT NULL PRIMARY KEY REFERENCES extension(id) ON UPDATE CASCADE ON DELETE CASCADE)",
            "CREATE TABLE graphics (hash TEXT NOT NULL PRIMARY KEY,file_size INTEGER NOT NULL, original_name TEXT NOT NULL, content BLOB NOT NULL)",
            "CREATE INDEX field__field_id ON field (field_id)",
            "CREATE INDEX extension__typecode ON extension (typecode)",
        ])
        let doc = try DSIReader.read(data)
        #expect(doc.meta == ["kind": "dsi", "versions": "300, 301, 302, 303"])
        #expect(doc.phones.isEmpty)
        #expect(Array(data[18...19]) == [1, 1])  // rollback-journal file format, like DESI's files
    }

    @Test func newDatabaseAcceptsAPhone() throws {
        let data = try DSIWriter.emptyDatabase()
        let previous = try DSIReader.read(data)
        var current = previous
        current.phones.append(Phone(id: "118", typecode: "AWX9212", name: "A", modified: "20260922T120000", fields: [
            5096: PhoneLabel(text: LabelText.template(forFieldID: 5096).replacingText("Hi")),
        ]))
        current.selectedPhoneID = "118"
        let written = try DSIWriter.write(current, previous: previous, original: data)
        try Self.expectHealthy(written)
        let reread = try DSIReader.read(written)
        #expect(reread.phones.map(\.id) == ["118"])
        #expect(reread.selectedPhoneID == "118")
        #expect(reread.phones[0].label(forKey: 1)?.text.plainText == "Hi")
    }
}
