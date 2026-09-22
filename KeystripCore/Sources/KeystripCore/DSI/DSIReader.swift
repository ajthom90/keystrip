import Foundation

public enum DSIError: Error, LocalizedError, Equatable, Sendable {
    case notADESIDatabase
    case duplicatePhoneID(String)

    public var errorDescription: String? {
        switch self {
        case .notADESIDatabase: "This file is not a DESI database."
        case .duplicatePhoneID(let id): "Two phones have the ID \"\(id)\"."
        }
    }
}

public enum DSIReader {
    public static func read(_ data: Data) throws -> DSIDocumentData {
        let db: SQLiteDatabase
        do {
            db = try SQLiteDatabase(data: data)
            let kind = try db.query("SELECT value FROM meta WHERE key = 'kind'").first?.first?.stringValue
            guard kind == "dsi" else { throw DSIError.notADESIDatabase }
        } catch let error as DSIError {
            throw error
        } catch {
            throw DSIError.notADESIDatabase
        }
        return try read(from: db)
    }

    static func read(from db: SQLiteDatabase) throws -> DSIDocumentData {
        var meta: [String: String] = [:]
        for row in try db.query("SELECT key, value FROM meta") {
            if let key = row[0].stringValue { meta[key] = row[1].stringValue ?? "" }
        }

        var fieldsByPhone: [String: [Int: PhoneLabel]] = [:]
        for row in try db.query("SELECT extension_id, field_id, content FROM field") {
            guard let phoneID = row[0].stringValue, let fieldID = row[1].intValue else { continue }
            fieldsByPhone[phoneID, default: [:]][fieldID] = PhoneLabel(rtf: row[2].stringValue ?? "")
        }

        let phones = try db.query("SELECT id, typecode, name, modified FROM extension ORDER BY rowid").compactMap { row -> Phone? in
            guard let id = row[0].stringValue else { return nil }
            return Phone(
                id: id,
                typecode: row[1].stringValue ?? "",
                name: row[2].stringValue ?? "",
                modified: row[3].stringValue ?? "",
                fields: fieldsByPhone[id] ?? [:]
            )
        }

        let selected = try db.query("SELECT extension_id FROM selections ORDER BY rowid LIMIT 1").first?.first?.stringValue
        return DSIDocumentData(meta: meta, phones: phones, selectedPhoneID: selected)
    }
}
