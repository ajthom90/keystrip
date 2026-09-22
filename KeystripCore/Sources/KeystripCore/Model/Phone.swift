/// One `extension` row and its labels. DESI calls a phone an "extension".
public struct Phone: Identifiable, Equatable, Sendable {
    public var id: String
    public var typecode: String
    public var name: String
    public var modified: String
    public var fields: [Int: PhoneLabel]

    public init(id: String, typecode: String, name: String, modified: String, fields: [Int: PhoneLabel] = [:]) {
        self.id = id
        self.typecode = typecode
        self.name = name
        self.modified = modified
        self.fields = fields
    }

    public var model: PhoneModel? { PhoneCatalog.model(for: typecode) }

    public var keyCount: Int { PhoneCatalog.keyCount(typecode: typecode, fieldIDs: fields.keys) }

    public var keyFieldIDs: [Int] {
        keyCount > 0 ? (1...keyCount).map(PhoneModel.fieldID(forKey:)) : []
    }

    /// Fields that are neither the name strip nor one of this model's keys. Preserved, not shown.
    public var otherFieldIDs: [Int] {
        let shown = Set(keyFieldIDs + [PhoneModel.nameStripFieldID])
        return fields.keys.filter { !shown.contains($0) }.sorted()
    }

    public var nameStrip: PhoneLabel? { fields[PhoneModel.nameStripFieldID] }

    public func label(forKey key: Int) -> PhoneLabel? { fields[PhoneModel.fieldID(forKey: key)] }
}

/// Everything Keystrip reads from a `.dsi` file.
public struct DSIDocumentData: Equatable, Sendable {
    public var meta: [String: String]
    public var phones: [Phone]
    public var selectedPhoneID: String?

    public init(meta: [String: String] = [:], phones: [Phone] = [], selectedPhoneID: String? = nil) {
        self.meta = meta
        self.phones = phones
        self.selectedPhoneID = selectedPhoneID
    }

    public func phone(withID id: String) -> Phone? { phones.first { $0.id == id } }

    public func index(ofPhone id: String) -> Int? { phones.firstIndex { $0.id == id } }
}
