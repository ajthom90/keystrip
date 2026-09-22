import Foundation
import Testing
@testable import KeystripCore

struct DSIReaderTests {
    @Test func readsPhonesInFileOrderWithMetaAndSelection() throws {
        let doc = try Fixture.document()
        #expect(doc.phones.map(\.id) == ["101", "Template", "240", "300", "102"])
        #expect(doc.meta == ["kind": "dsi", "versions": "300, 301, 302, 303"])
        #expect(doc.selectedPhoneID == "102")
    }

    @Test func readsPhoneColumnsAndFields() throws {
        let phone = try #require(try Fixture.document().phone(withID: "101"))
        #expect(phone.typecode == "AWX9212")
        #expect(phone.name == "Alex Rivera")
        #expect(phone.modified == "20240102T090000")
        #expect(phone.fields.count == 13)
        #expect(phone.model?.keyCount == 12)
        #expect(phone.nameStrip?.text.plainText == "Alex x101")
        #expect(phone.label(forKey: 1)?.text.plainText == "Page\nPhones")
        #expect(phone.label(forKey: 8)?.text.plainText == "Park\n703")
        #expect(phone.otherFieldIDs.isEmpty)
    }

    @Test func blankKeysHaveNoLabel() throws {
        let phone = try #require(try Fixture.document().phone(withID: "Template"))
        #expect(phone.name == "")
        #expect(phone.label(forKey: 5) == nil)
        #expect(phone.label(forKey: 3)?.text.isBlank == true)
        #expect(phone.label(forKey: 3)?.text.baseStyle == TextStyle(bold: true))
        #expect(phone.label(forKey: 4)?.text.baseStyle == TextStyle())
    }

    @Test func readsA24KeyPhone() throws {
        let phone = try #require(try Fixture.document().phone(withID: "240"))
        #expect(phone.keyCount == 24)
        #expect(phone.keyFieldIDs.count == 24)
        #expect(phone.label(forKey: 24)?.text.plainText == "Key 24")
        #expect(phone.label(forKey: 1)?.text.fontSize == 16)
    }

    @Test func unknownModelsInferKeysAndKeepOtherFields() throws {
        let phone = try #require(try Fixture.document().phone(withID: "300"))
        #expect(phone.model == nil)
        #expect(phone.keyCount == 3)
        #expect(phone.label(forKey: 2) == nil)
        #expect(phone.label(forKey: 3)?.text.plainText == "Three")
        #expect(phone.otherFieldIDs == [5])
    }

    @Test func unusualLabelsAreReadSafely() throws {
        let phone = try #require(try Fixture.document().phone(withID: "102"))
        #expect(phone.label(forKey: 1)?.text.color == RGBColor(red: 0, green: 64, blue: 64))
        #expect(phone.label(forKey: 3)?.text.plainText == "Café")
        #expect(phone.label(forKey: 4)?.text.hasMixedRuns == true)
        #expect(phone.label(forKey: 7)?.text.plainText == "Ā")
        let unreadable = try #require(phone.label(forKey: 6))
        #expect(unreadable.isUnreadable)
        #expect(!unreadable.isEdited)
        #expect(unreadable.rtfForWriting == "not rtf at all")
    }

    @Test func everyDESIStyleLabelRoundTripsByteForByte() throws {
        for phone in try Fixture.document().phones {
            for (fieldID, label) in phone.fields where !label.isUnreadable {
                let original = try #require(label.originalRTF)
                guard !original.contains(#"\deff0"#) else { continue }  // the deliberately odd label
                #expect(RTFWriter.write(try #require(label.originalText)) == original, "phone \(phone.id) field \(fieldID)")
            }
        }
    }

    @Test func rejectsFilesThatAreNotDESIDatabases() throws {
        #expect(throws: DSIError.notADESIDatabase) { try DSIReader.read(Data("hello".utf8)) }
        #expect(throws: DSIError.notADESIDatabase) { try DSIReader.read(Data()) }

        let noMeta = try SQLiteDatabase()
        try noMeta.execute("CREATE TABLE t (a)")
        #expect(throws: DSIError.notADESIDatabase) { try DSIReader.read(try noMeta.serialize()) }

        let otherKind = try SQLiteDatabase()
        try otherKind.execute("CREATE TABLE meta (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL DEFAULT (''))")
        try otherKind.execute("INSERT INTO meta VALUES ('kind', 'ddfcache')")
        #expect(throws: DSIError.notADESIDatabase) { try DSIReader.read(try otherKind.serialize()) }
    }

    @Test func errorMessagesAreReadable() {
        #expect(DSIError.notADESIDatabase.errorDescription == "This file is not a DESI database.")
        #expect(DSIError.duplicatePhoneID("118").errorDescription == "Two phones have the ID \"118\".")
    }

    @Test func phoneLabelEditTracking() throws {
        var label = PhoneLabel(rtf: Fixture.header + #"\b Sam}"#)
        #expect(!label.isEdited)
        #expect(label.rtfForWriting == Fixture.header + #"\b Sam}"#)

        label.text = label.text.replacingText("Pat")
        #expect(label.isEdited)
        #expect(label.rtfForWriting == Fixture.header + #"\b Pat}"#)

        label.text = label.text.replacingText("Sam")
        #expect(!label.isEdited)

        let odd = #"{\rtf1\ansi\deff0{\fonttbl{\f0\fswiss Arial;}}\f0\fs18\qc\b Odd}"#
        #expect(PhoneLabel(rtf: odd).rtfForWriting == odd)

        let fresh = PhoneLabel(text: LabelText.template(forFieldID: 5096).replacingText("New"))
        #expect(fresh.isEdited)
        #expect(fresh.originalRTF == nil)
        #expect(fresh.rtfForWriting == Fixture.header + #"\b New}"#)
    }
}
