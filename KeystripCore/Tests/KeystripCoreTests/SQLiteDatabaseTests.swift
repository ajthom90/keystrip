import Foundation
import Testing
@testable import KeystripCore

struct SQLiteDatabaseTests {
    @Test func bindsAndReadsEveryValueType() throws {
        let db = try SQLiteDatabase()
        try db.execute("CREATE TABLE t (a TEXT, b INTEGER, c BLOB, d REAL, e TEXT)")
        try db.execute(
            "INSERT INTO t VALUES (?, ?, ?, ?, ?)",
            [.text("héllo {x}"), .integer(42), .blob(Data([1, 2, 3])), .real(1.5), .null]
        )
        let rows = try db.query("SELECT a, b, c, d, e FROM t")
        #expect(rows == [[.text("héllo {x}"), .integer(42), .blob(Data([1, 2, 3])), .real(1.5), .null]])
    }

    @Test func valueConveniences() {
        #expect(SQLiteValue.text("118").stringValue == "118")
        #expect(SQLiteValue.integer(118).stringValue == "118")
        #expect(SQLiteValue.null.stringValue == nil)
        #expect(SQLiteValue.integer(5096).intValue == 5096)
        #expect(SQLiteValue.text("5096").intValue == 5096)
        #expect(SQLiteValue.blob(Data()).intValue == nil)
    }

    @Test func serializesAndReloadsKeepingEncodingAndPageSize() throws {
        let db = try SQLiteDatabase()
        try db.execute("PRAGMA encoding='UTF-16le'")
        try db.execute("PRAGMA page_size=1024")
        try db.execute("CREATE TABLE t (a TEXT)")
        try db.execute("INSERT INTO t VALUES (?)", [.text("x")])
        let data = try db.serialize()
        #expect(data.prefix(16) == Data("SQLite format 3\0".utf8))

        let copy = try SQLiteDatabase(data: data)
        #expect(try copy.query("SELECT a FROM t") == [[.text("x")]])
        #expect(try copy.query("PRAGMA encoding") == [[.text("UTF-16le")]])
        #expect(try copy.query("PRAGMA page_size") == [[.integer(1024)]])
    }

    @Test func reloadedCopyIsIndependentOfTheSourceBytes() throws {
        let db = try SQLiteDatabase()
        try db.execute("CREATE TABLE t (a INTEGER)")
        try db.execute("INSERT INTO t VALUES (1)")
        let original = try db.serialize()

        let copy = try SQLiteDatabase(data: original)
        try copy.execute("INSERT INTO t VALUES (2)")
        #expect(try copy.query("SELECT count(*) FROM t") == [[.integer(2)]])

        let second = try SQLiteDatabase(data: original)
        #expect(try second.query("SELECT count(*) FROM t") == [[.integer(1)]])
    }

    @Test func transactionRollsBackWhenTheBodyThrows() throws {
        let db = try SQLiteDatabase()
        try db.execute("CREATE TABLE t (a INTEGER PRIMARY KEY)")
        #expect(throws: SQLiteError.self) {
            try db.transaction {
                try db.execute("INSERT INTO t VALUES (1)")
                try db.execute("INSERT INTO t VALUES (1)")
            }
        }
        #expect(try db.query("SELECT count(*) FROM t") == [[.integer(0)]])
    }

    @Test func transactionCommitsWhenTheBodySucceeds() throws {
        let db = try SQLiteDatabase()
        try db.execute("CREATE TABLE t (a INTEGER)")
        try db.transaction { try db.execute("INSERT INTO t VALUES (7)") }
        #expect(try db.query("SELECT a FROM t") == [[.integer(7)]])
    }

    @Test func garbageBytesAreRejected() {
        let garbage = Data(String(repeating: "not a database ", count: 20).utf8)
        #expect(throws: SQLiteError.self) {
            let db = try SQLiteDatabase(data: garbage)
            try db.query("SELECT * FROM sqlite_master")
        }
    }

    @Test func errorsCarryTheSQLiteMessage() throws {
        let db = try SQLiteDatabase()
        let error = #expect(throws: SQLiteError.self) {
            try db.execute("SELEC nonsense")
        }
        #expect(error?.message.contains("syntax error") == true)
        #expect(error?.errorDescription?.hasPrefix("SQLite reported:") == true)
    }
}
