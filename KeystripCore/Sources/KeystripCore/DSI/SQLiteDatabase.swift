import Foundation
import SQLite3

/// A value read from or bound to SQLite.
public enum SQLiteValue: Equatable, Sendable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)

    public var stringValue: String? {
        switch self {
        case .text(let value): value
        case .integer(let value): String(value)
        case .real(let value): String(value)
        case .null, .blob: nil
        }
    }

    public var intValue: Int? {
        switch self {
        case .integer(let value): Int(exactly: value)
        case .text(let value): Int(value)
        case .real(let value): Int(exactly: value)
        case .null, .blob: nil
        }
    }
}

public struct SQLiteError: Error, LocalizedError, Equatable, Sendable {
    public let code: Int32
    public let message: String

    public init(code: Int32, message: String) {
        self.code = code
        self.message = message
    }

    public var errorDescription: String? { "SQLite reported: \(message) (code \(code))" }
}

/// A thin wrapper over one in-memory SQLite connection.
/// Not thread-safe: create, use, and discard it on one thread.
public final class SQLiteDatabase {
    private let handle: OpaquePointer

    /// Opens an empty in-memory database.
    public init() throws {
        var db: OpaquePointer?
        let rc = sqlite3_open_v2(":memory:", &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard rc == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "could not open database"
            sqlite3_close(db)
            throw SQLiteError(code: rc, message: message)
        }
        handle = db
    }

    /// Opens an in-memory database holding a private copy of `data`.
    public convenience init(data: Data) throws {
        try self.init()
        try load(data)
    }

    deinit {
        sqlite3_close(handle)
    }

    private func load(_ data: Data) throws {
        let size = data.count
        guard let raw = sqlite3_malloc64(sqlite3_uint64(max(size, 1))) else {
            throw SQLiteError(code: SQLITE_NOMEM, message: "out of memory")
        }
        let buffer = raw.assumingMemoryBound(to: UInt8.self)
        data.copyBytes(to: buffer, count: size)
        // With FREEONCLOSE, SQLite owns the buffer from here on, even if this call fails.
        let flags = UInt32(SQLITE_DESERIALIZE_FREEONCLOSE | SQLITE_DESERIALIZE_RESIZEABLE)
        let rc = sqlite3_deserialize(handle, "main", buffer, sqlite3_int64(size), sqlite3_int64(size), flags)
        guard rc == SQLITE_OK else { throw lastError(rc) }
    }

    /// Returns the complete database file as bytes.
    public func serialize() throws -> Data {
        var size: sqlite3_int64 = 0
        guard let pointer = sqlite3_serialize(handle, "main", &size, 0) else {
            throw SQLiteError(code: SQLITE_NOMEM, message: "could not serialize database")
        }
        defer { sqlite3_free(pointer) }
        return Data(bytes: pointer, count: Int(size))
    }

    public func execute(_ sql: String, _ parameters: [SQLiteValue] = []) throws {
        try query(sql, parameters)
    }

    @discardableResult
    public func query(_ sql: String, _ parameters: [SQLiteValue] = []) throws -> [[SQLiteValue]] {
        var statement: OpaquePointer?
        let rc = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard rc == SQLITE_OK, let statement else { throw lastError(rc) }
        defer { sqlite3_finalize(statement) }

        for (offset, value) in parameters.enumerated() {
            try bind(value, at: Int32(offset + 1), in: statement)
        }

        var rows: [[SQLiteValue]] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW else { throw lastError(step) }
            let columns = sqlite3_column_count(statement)
            rows.append((0..<columns).map { column($0, in: statement) })
        }
        return rows
    }

    /// Runs `body` inside BEGIN/COMMIT, rolling back if it throws.
    public func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN")
        do {
            try body()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func bind(_ value: SQLiteValue, at index: Int32, in statement: OpaquePointer) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let rc: Int32
        switch value {
        case .null:
            rc = sqlite3_bind_null(statement, index)
        case .integer(let number):
            rc = sqlite3_bind_int64(statement, index, number)
        case .real(let number):
            rc = sqlite3_bind_double(statement, index, number)
        case .text(let string):
            rc = sqlite3_bind_text(statement, index, string, -1, transient)
        case .blob(let bytes):
            rc = bytes.withUnsafeBytes { buffer in
                sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), transient)
            }
        }
        guard rc == SQLITE_OK else { throw lastError(rc) }
    }

    private func column(_ index: Int32, in statement: OpaquePointer) -> SQLiteValue {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER:
            return .integer(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT:
            return .real(sqlite3_column_double(statement, index))
        case SQLITE_TEXT:
            guard let text = sqlite3_column_text(statement, index) else { return .text("") }
            let count = Int(sqlite3_column_bytes(statement, index))
            return .text(String(decoding: UnsafeBufferPointer(start: text, count: count), as: UTF8.self))
        case SQLITE_BLOB:
            let count = Int(sqlite3_column_bytes(statement, index))
            guard count > 0, let bytes = sqlite3_column_blob(statement, index) else { return .blob(Data()) }
            return .blob(Data(bytes: bytes, count: count))
        default:
            return .null
        }
    }

    private func lastError(_ code: Int32) -> SQLiteError {
        SQLiteError(code: code, message: String(cString: sqlite3_errmsg(handle)))
    }
}
