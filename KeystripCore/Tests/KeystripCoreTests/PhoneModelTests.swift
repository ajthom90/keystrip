import Testing
@testable import KeystripCore

struct PhoneModelTests {
    @Test func fieldIDsFollowDESIsNumbering() {
        #expect(PhoneModel.nameStripFieldID == 4796)
        #expect(PhoneModel.fieldID(forKey: 1) == 5096)
        #expect(PhoneModel.fieldID(forKey: 12) == 16096)
        #expect(PhoneModel.fieldID(forKey: 24) == 28096)
    }

    @Test func keyIndexIsTheInverseOfFieldID() {
        for key in 1...24 {
            #expect(PhoneModel.keyIndex(forFieldID: PhoneModel.fieldID(forKey: key)) == key)
        }
        #expect(PhoneModel.keyIndex(forFieldID: 4796) == nil)
        #expect(PhoneModel.keyIndex(forFieldID: 5) == nil)
        #expect(PhoneModel.keyIndex(forFieldID: 5097) == nil)
    }

    @Test func catalogKnowsTheAllworxPhones() throws {
        let m12 = try #require(PhoneCatalog.model(for: "AWX9212"))
        #expect(m12.keyCount == 12)
        #expect(m12.displayName == "Allworx 9212")
        #expect(m12.keyFieldIDs.first == 5096)
        #expect(m12.keyFieldIDs.last == 16096)
        let m24 = try #require(PhoneCatalog.model(for: "AWX9224"))
        #expect(m24.keyCount == 24)
        #expect(PhoneCatalog.model(for: "awx9212") == nil)
        #expect(PhoneCatalog.defaultModel == m12)
        #expect(PhoneCatalog.known.map(\.typecode) == ["AWX9212", "AWX9224"])
    }

    @Test func displayNameFallsBackForUnknownModels() {
        #expect(PhoneCatalog.displayName(for: "AWX9224") == "Allworx 9224")
        #expect(PhoneCatalog.displayName(for: "ZZ9999") == "Other (ZZ9999)")
    }

    @Test func keyCountUsesTheModelOrInfersFromFields() {
        #expect(PhoneCatalog.keyCount(typecode: "AWX9212", fieldIDs: [4796, 28096]) == 12)
        #expect(PhoneCatalog.keyCount(typecode: "ZZ9999", fieldIDs: [4796, 5, 5096, 7096]) == 3)
        #expect(PhoneCatalog.keyCount(typecode: "ZZ9999", fieldIDs: [4796, 5]) == 0)
    }
}
