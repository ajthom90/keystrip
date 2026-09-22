import Foundation
import Testing
@testable import KeystripCore

struct DocumentEditingTests {
    let now = "20260922T120000"

    @Test func validatesPhoneIDs() throws {
        let doc = try Fixture.document()
        #expect(try doc.validatedPhoneID("  118 ") == "118")
        #expect(throws: EditError.emptyPhoneID) { try doc.validatedPhoneID("   ") }
        #expect(throws: EditError.duplicatePhoneID("101")) { try doc.validatedPhoneID("101") }
        #expect(try doc.validatedPhoneID("101", excluding: "101") == "101")
        #expect(EditError.emptyPhoneID.errorDescription == "A phone needs an ID.")
        #expect(EditError.duplicatePhoneID("101").errorDescription == "A phone with the ID \"101\" already exists.")
        #expect(EditError.noSuchPhone("9").errorDescription == "There is no phone with the ID \"9\".")
    }

    @Test func addsABlankPhone() throws {
        var doc = try Fixture.document()
        let id = try doc.addPhone(id: " 118 ", name: "New", typecode: "AWX9224", now: now)
        #expect(id == "118")
        #expect(doc.phones.last == Phone(id: "118", typecode: "AWX9224", name: "New", modified: now))
    }

    @Test func addsAPhoneFromATemplateWithoutItsNameStrip() throws {
        var doc = try Fixture.document()
        try doc.addPhone(id: "119", name: "", typecode: "AWX9212", copyingFrom: "Template", now: now)
        let phone = try #require(doc.phone(withID: "119"))
        let template = try #require(doc.phone(withID: "Template"))
        #expect(phone.nameStrip == nil)
        #expect(Set(phone.fields.keys) == Set(template.fields.keys).subtracting([4796]))
        for (fieldID, label) in phone.fields {
            #expect(label.rtfForWriting == template.fields[fieldID]?.rtfForWriting)
            #expect(!label.isEdited)
        }
    }

    @Test func duplicatingIncludesTheNameStripAndOddLabels() throws {
        var doc = try Fixture.document()
        try doc.addPhone(id: "104", name: "Chris Ng", typecode: "AWX9212", copyingFrom: "102", includeNameStrip: true, now: now)
        let copy = try #require(doc.phone(withID: "104"))
        let source = try #require(doc.phone(withID: "102"))
        #expect(copy.fields.mapValues(\.rtfForWriting) == source.fields.mapValues(\.rtfForWriting))
        #expect(copy.label(forKey: 6)?.isUnreadable == true)
    }

    @Test func addRejectsBadIDsAndMissingSources() throws {
        var doc = try Fixture.document()
        #expect(throws: EditError.duplicatePhoneID("101")) { try doc.addPhone(id: "101", name: "", typecode: "AWX9212") }
        #expect(throws: EditError.noSuchPhone("nope")) { try doc.addPhone(id: "1", name: "", typecode: "AWX9212", copyingFrom: "nope") }
        #expect(doc.phones.count == 5)
    }

    @Test func deletesAPhoneAndClearsItsSelection() throws {
        var doc = try Fixture.document()
        try doc.deletePhone(id: "102")
        #expect(doc.phone(withID: "102") == nil)
        #expect(doc.selectedPhoneID == nil)
        try doc.deletePhone(id: "101")
        #expect(doc.phones.map(\.id) == ["Template", "240", "300"])
        #expect(throws: EditError.noSuchPhone("101")) { try doc.deletePhone(id: "101") }
    }

    @Test func renamesAPhoneAndItsSelection() throws {
        var doc = try Fixture.document()
        #expect(try doc.renamePhone(id: "102", to: " 103 ", now: now) == "103")
        #expect(doc.selectedPhoneID == "103")
        #expect(doc.phone(withID: "103")?.modified == now)
        #expect(throws: EditError.duplicatePhoneID("101")) { try doc.renamePhone(id: "103", to: "101") }

        let before = doc
        #expect(try doc.renamePhone(id: "103", to: "103", now: "20990101T000000") == "103")
        #expect(doc == before)
    }

    @Test func setsNameAndTypecodeOnlyWhenChanged() throws {
        var doc = try Fixture.document()
        try doc.setName("Alex Rivera", phoneID: "101", now: now)
        #expect(doc.phone(withID: "101")?.modified == "20240102T090000")
        try doc.setName("Alex R.", phoneID: "101", now: now)
        #expect(doc.phone(withID: "101")?.name == "Alex R.")
        #expect(doc.phone(withID: "101")?.modified == now)
        try doc.setTypecode("AWX9224", phoneID: "Template", now: now)
        #expect(doc.phone(withID: "Template")?.keyCount == 24)
        #expect(throws: EditError.noSuchPhone("x")) { try doc.setName("a", phoneID: "x") }
    }

    @Test func editsExistingLabelText() throws {
        var doc = try Fixture.document()
        try doc.setLabelText("Pat\r\nLee", phoneID: "101", fieldID: 7096, now: now)
        let label = try #require(doc.phone(withID: "101")?.fields[7096])
        #expect(label.text.plainText == "Pat\nLee")
        #expect(label.text.baseStyle == TextStyle(bold: true))
        #expect(label.rtfForWriting == Fixture.header + #"\b Pat\par Lee}"#)
        #expect(doc.phone(withID: "101")?.modified == now)
    }

    @Test func sameTextIsANoOp() throws {
        var doc = try Fixture.document()
        let before = doc
        try doc.setLabelText("Sam", phoneID: "101", fieldID: 7096, now: now)
        #expect(doc == before)
    }

    @Test func sameTextOnAMixedFormatLabelKeepsItsRuns() throws {
        var doc = try Fixture.document()
        let before = doc
        try doc.setLabelText("Ben S", phoneID: "102", fieldID: 8096, now: now)
        #expect(doc == before)
        #expect(doc.phone(withID: "102")?.fields[8096]?.isEdited == false)
    }

    @Test func typingIntoABlankKeyCreatesABoldLabel() throws {
        var doc = try Fixture.document()
        try doc.setLabelText("", phoneID: "Template", fieldID: 9096, now: now)
        #expect(doc.phone(withID: "Template")?.fields[9096] == nil)
        try doc.setLabelText("New", phoneID: "Template", fieldID: 9096, now: now)
        #expect(doc.phone(withID: "Template")?.fields[9096]?.rtfForWriting == Fixture.header + #"\b New}"#)
    }

    @Test func clearingKeepsFileLabelsButRemovesNewOnes() throws {
        var doc = try Fixture.document()
        try doc.setLabelText("", phoneID: "101", fieldID: 7096, now: now)
        #expect(doc.phone(withID: "101")?.fields[7096]?.rtfForWriting == Fixture.header + #"\b }"#)

        try doc.setLabelText("Temp", phoneID: "Template", fieldID: 9096, now: now)
        try doc.setLabelText("", phoneID: "Template", fieldID: 9096, now: now)
        #expect(doc.phone(withID: "Template")?.fields[9096] == nil)
    }

    @Test func unreadableLabelsAreReadOnly() throws {
        var doc = try Fixture.document()
        let before = doc
        try doc.setLabelText("x", phoneID: "102", fieldID: 10096, now: now)
        try doc.updateLabelFormat(phoneID: "102", fieldID: 10096, now: now) { $0.style.bold = false }
        #expect(doc == before)
    }

    @Test func updatesLabelFormat() throws {
        var doc = try Fixture.document()
        try doc.updateLabelFormat(phoneID: "101", fieldID: 7096, now: now) { format in
            format.fontSize = 16
            format.style = TextStyle(italic: true)
            format.alignment = .left
        }
        let rtf = try #require(doc.phone(withID: "101")?.fields[7096]?.rtfForWriting)
        #expect(rtf == #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs16\ql\i Sam}"#)

        let before = doc
        try doc.updateLabelFormat(phoneID: "101", fieldID: 7096, now: "20990101T000000") { _ in }
        #expect(doc == before)
    }

    @Test func formattingABlankKeyCreatesAnEmptyLabel() throws {
        var doc = try Fixture.document()
        try doc.updateLabelFormat(phoneID: "Template", fieldID: 9096, now: now) { $0.fontSize = 16 }
        #expect(doc.phone(withID: "Template")?.fields[9096]?.rtfForWriting == #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs16\qc\b }"#)
    }

    @Test func editsRoundTripThroughTheWriter() throws {
        let data = try Fixture.data()
        let previous = try DSIReader.read(data)
        var doc = previous
        try doc.setLabelText("Pat", phoneID: "101", fieldID: 7096, now: now)
        try doc.addPhone(id: "119", name: "Copy", typecode: "AWX9212", copyingFrom: "Template", now: now)
        try doc.renamePhone(id: "300", to: "301", now: now)
        try doc.deletePhone(id: "240")
        let written = try DSIWriter.write(doc, previous: previous, original: data)
        let reread = try DSIReader.read(written)
        #expect(reread.phones.map(\.id).sorted() == doc.phones.map(\.id).sorted())
        for phone in doc.phones {
            let saved = try #require(reread.phone(withID: phone.id))
            #expect(saved.fields.mapValues(\.rtfForWriting) == phone.fields.mapValues(\.rtfForWriting))
            #expect(saved.name == phone.name)
            #expect(saved.modified == phone.modified)
        }
    }
}
