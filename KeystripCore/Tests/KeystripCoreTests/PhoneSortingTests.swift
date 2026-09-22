import Testing
@testable import KeystripCore

struct PhoneSortingTests {
    func phone(_ id: String, _ name: String = "") -> Phone {
        Phone(id: id, typecode: "AWX9212", name: name, modified: "")
    }

    @Test func sortsIDsNaturally() {
        let phones = ["X135", "118", "10", "9", "Standard", "1"].map { phone($0) }
        #expect(PhoneSorting.sorted(phones, by: .id).map(\.id) == ["1", "9", "10", "118", "Standard", "X135"])
    }

    @Test func sortsByNameWithUnnamedPhonesLast() {
        let phones = [phone("3", "bea"), phone("1"), phone("4", "Al"), phone("2", "Al"), phone("0")]
        #expect(PhoneSorting.sorted(phones, by: .name).map(\.id) == ["2", "4", "3", "0", "1"])
    }

    @Test func filtersByIDOrNameIgnoringCase() {
        let phones = [phone("118", "Andrew"), phone("X135", "Lab"), phone("140", "R&D Entrance")]
        #expect(PhoneSorting.filter(phones, matching: "  ").map(\.id) == ["118", "X135", "140"])
        #expect(PhoneSorting.filter(phones, matching: "x1").map(\.id) == ["X135"])
        #expect(PhoneSorting.filter(phones, matching: "r&d").map(\.id) == ["140"])
        #expect(PhoneSorting.filter(phones, matching: "1").map(\.id) == ["118", "X135", "140"])
    }
}
