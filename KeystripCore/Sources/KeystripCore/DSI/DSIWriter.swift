import Foundation

public enum DSIWriter {
    public static func write(_ current: DSIDocumentData, previous: DSIDocumentData, original: Data) throws -> Data {
        if let duplicate = firstDuplicateID(in: current) {
            throw DSIError.duplicatePhoneID(duplicate)
        }
        let db = try SQLiteDatabase(data: original)
        try db.execute("PRAGMA foreign_keys=ON")
        try db.transaction {
            try applyDifference(current, previous: previous, to: db)
        }
        return try db.serialize()
    }

    public static func emptyDatabase() throws -> Data {
        let db = try SQLiteDatabase()
        try db.execute("PRAGMA encoding='UTF-16le'")
        try db.execute("PRAGMA page_size=1024")
        for statement in DSISchema.createStatements {
            try db.execute(statement)
        }
        try db.execute("INSERT INTO meta (key, value) VALUES (?, ?)", [.text("kind"), .text("dsi")])
        try db.execute("INSERT INTO meta (key, value) VALUES (?, ?)", [.text("versions"), .text(DSISchema.versions)])
        return try db.serialize()
    }

    /// The first id that appears twice, walking `current.phones` in order.
    private static func firstDuplicateID(in document: DSIDocumentData) -> String? {
        var seen: Set<String> = []
        for phone in document.phones {
            if !seen.insert(phone.id).inserted { return phone.id }
        }
        return nil
    }

    private static func applyDifference(_ current: DSIDocumentData, previous: DSIDocumentData, to db: SQLiteDatabase) throws {
        var previousByID: [String: Phone] = [:]
        for phone in previous.phones {
            previousByID[phone.id] = phone
        }
        let currentIDs = Set(current.phones.map(\.id))

        for phone in previous.phones where !currentIDs.contains(phone.id) {
            try deletePhone(id: phone.id, from: db)
        }

        for phone in current.phones {
            if let old = previousByID[phone.id] {
                try update(phone, from: old, in: db)
            } else {
                try insert(phone, into: db)
            }
        }

        if current.selectedPhoneID != previous.selectedPhoneID,
           let selected = current.selectedPhoneID,
           currentIDs.contains(selected) {
            try db.execute("DELETE FROM selections")
            try db.execute("INSERT INTO selections (extension_id) VALUES (?)", [.text(selected)])
        }
    }

    private static func deletePhone(id: String, from db: SQLiteDatabase) throws {
        try db.execute("DELETE FROM field WHERE extension_id=?", [.text(id)])
        try db.execute("DELETE FROM selections WHERE extension_id=?", [.text(id)])
        try db.execute("DELETE FROM extension WHERE id=?", [.text(id)])
    }

    private static func insert(_ phone: Phone, into db: SQLiteDatabase) throws {
        try db.execute(
            "INSERT INTO extension (id, typecode, name, modified) VALUES (?, ?, ?, ?)",
            [.text(phone.id), .text(phone.typecode), .text(phone.name), .text(phone.modified)]
        )
        for fieldID in phone.fields.keys.sorted() {
            guard let label = phone.fields[fieldID] else { continue }
            try writeField(fieldID, label, phoneID: phone.id, to: db)
        }
    }

    private static func update(_ phone: Phone, from old: Phone, in db: SQLiteDatabase) throws {
        if phone.typecode != old.typecode || phone.name != old.name || phone.modified != old.modified {
            try db.execute(
                "UPDATE extension SET typecode=?, name=?, modified=? WHERE id=?",
                [.text(phone.typecode), .text(phone.name), .text(phone.modified), .text(phone.id)]
            )
        }
        for fieldID in Set(old.fields.keys).union(phone.fields.keys).sorted() {
            switch (old.fields[fieldID], phone.fields[fieldID]) {
            case (_, nil):
                try db.execute(
                    "DELETE FROM field WHERE extension_id=? AND field_id=?",
                    [.text(phone.id), .integer(Int64(fieldID))]
                )
            case (let previous?, let label?) where previous != label:
                try writeField(fieldID, label, phoneID: phone.id, to: db)
            case (nil, let label?):
                try writeField(fieldID, label, phoneID: phone.id, to: db)
            default:
                break
            }
        }
    }

    private static func writeField(_ fieldID: Int, _ label: PhoneLabel, phoneID: String, to db: SQLiteDatabase) throws {
        try db.execute(
            "INSERT OR REPLACE INTO field (extension_id, field_id, content) VALUES (?, ?, ?)",
            [.text(phoneID), .integer(Int64(fieldID)), .text(label.rtfForWriting)]
        )
    }
}
