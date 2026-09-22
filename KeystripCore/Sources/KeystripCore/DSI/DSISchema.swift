/// DESI's schema, verbatim from DESI Labeling System 3.8 (spec section 2.2), in `sqlite_master` order.
enum DSISchema {
    static let createStatements = [
        "CREATE TABLE meta (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL DEFAULT (''))",
        "CREATE TABLE extension (id TEXT NOT NULL PRIMARY KEY, typecode TEXT NOT NULL, name TEXT NOT NULL DEFAULT (''), modified TEXT NOT NULL)",
        "CREATE TABLE field (extension_id TEXT NOT NULL REFERENCES extension(id) ON UPDATE CASCADE ON DELETE CASCADE, field_id INTEGER NOT NULL, content TEXT NOT NULL DEFAULT (''), PRIMARY KEY (extension_id, field_id))",
        "CREATE TABLE selections (extension_id TEXT NOT NULL PRIMARY KEY REFERENCES extension(id) ON UPDATE CASCADE ON DELETE CASCADE)",
        "CREATE TABLE graphics (hash TEXT NOT NULL PRIMARY KEY,file_size INTEGER NOT NULL, original_name TEXT NOT NULL, content BLOB NOT NULL)",
        "CREATE INDEX field__field_id ON field (field_id)",
        "CREATE INDEX extension__typecode ON extension (typecode)",
    ]

    /// What current DESI versions record after migrating a new file.
    static let versions = "300, 301, 302, 303"
}
