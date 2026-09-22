import Foundation

/// A phone model DESI can print for. Field numbering is shared by all models.
public struct PhoneModel: Equatable, Hashable, Sendable, Identifiable {
    public let typecode: String
    public let displayName: String
    public let keyCount: Int

    public init(typecode: String, displayName: String, keyCount: Int) {
        self.typecode = typecode
        self.displayName = displayName
        self.keyCount = keyCount
    }

    public var id: String { typecode }

    public static let nameStripFieldID = 4796
    public static let firstKeyFieldID = 5096
    public static let keyFieldStride = 1000

    /// Field id of key `key` (1-based, top to bottom).
    public static func fieldID(forKey key: Int) -> Int {
        firstKeyFieldID + keyFieldStride * (key - 1)
    }

    /// The 1-based key for a field id, or nil when the id is not a key field.
    public static func keyIndex(forFieldID fieldID: Int) -> Int? {
        guard fieldID >= firstKeyFieldID, (fieldID - firstKeyFieldID) % keyFieldStride == 0 else { return nil }
        return (fieldID - firstKeyFieldID) / keyFieldStride + 1
    }

    public var keyFieldIDs: [Int] {
        keyCount > 0 ? (1...keyCount).map(Self.fieldID(forKey:)) : []
    }
}

public enum PhoneCatalog {
    public static let known: [PhoneModel] = [
        PhoneModel(typecode: "AWX9212", displayName: "Allworx 9212", keyCount: 12),
        PhoneModel(typecode: "AWX9224", displayName: "Allworx 9224", keyCount: 24),
    ]

    public static var defaultModel: PhoneModel { known[0] }

    public static func model(for typecode: String) -> PhoneModel? {
        known.first { $0.typecode == typecode }
    }

    public static func displayName(for typecode: String) -> String {
        model(for: typecode)?.displayName ?? "Other (\(typecode))"
    }

    /// The model's key count, or for an unknown model the highest key that has a field.
    public static func keyCount(typecode: String, fieldIDs: some Sequence<Int>) -> Int {
        if let model = model(for: typecode) { return model.keyCount }
        return fieldIDs.compactMap(PhoneModel.keyIndex(forFieldID:)).max() ?? 0
    }
}
