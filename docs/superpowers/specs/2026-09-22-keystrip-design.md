# Keystrip design

Date: 2026-09-22
Status: approved

## 1. Purpose

Keystrip is an open-source SwiftUI app for macOS, iPadOS, and iOS that edits
DESI Labeling System database files (`.dsi`) holding key labels for Allworx
desk phones. Printing stays in the free Windows DESI app. The goal is that a
file edited in Keystrip opens and prints in DESI Labeling System 3.8.x with
nothing changed except the edits the user made.

Non-goals for v1: printing, graphics and logos, Excel or CSV import and export,
DESI "codes" such as `[ExtID]`, per-selection (inline) formatting in the
editor, parsing DESI layout templates (DDF files), and the DESI pictogram font.

## 2. The `.dsi` file format

Everything in this section was verified against a real file and against the
SQL and RTF templates embedded in `desi.exe` (DESI Labeling System 3.8.23.0).

### 2.1 Container

- A standard SQLite 3 database. No encryption or obfuscation.
- Text encoding `UTF-16le`, page size 1024, journal mode `delete`.
- Written by DESI with SQLite 3.8.8.2. Apple's system SQLite (3.54) reads and
  writes it without any conversion; the encoding is fixed at creation and
  survives writes from newer SQLite versions.

### 2.2 Schema (verbatim from the DESI executable)

```sql
CREATE TABLE meta (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL DEFAULT (''));
CREATE TABLE extension (id TEXT NOT NULL PRIMARY KEY, typecode TEXT NOT NULL, name TEXT NOT NULL DEFAULT (''), modified TEXT NOT NULL);
CREATE TABLE field (extension_id TEXT NOT NULL REFERENCES extension(id) ON UPDATE CASCADE ON DELETE CASCADE, field_id INTEGER NOT NULL, content TEXT NOT NULL DEFAULT (''), PRIMARY KEY (extension_id, field_id));
CREATE INDEX field__field_id ON field (field_id);
CREATE INDEX extension__typecode ON extension (typecode);
CREATE TABLE selections (extension_id TEXT NOT NULL PRIMARY KEY REFERENCES extension(id) ON UPDATE CASCADE ON DELETE CASCADE);
CREATE TABLE graphics (hash TEXT NOT NULL PRIMARY KEY,file_size INTEGER NOT NULL, original_name TEXT NOT NULL, content BLOB NOT NULL);
```

The exact `CREATE` text matters: DESI compares nothing against it, but a new
file Keystrip creates must be indistinguishable from one DESI created, so the
statements above are reproduced character for character (including the
missing space after the comma in `graphics`).

### 2.3 Tables

`meta` holds two rows. `kind` is `dsi`. `versions` is a comma-and-space
separated list of the schema versions the file has been migrated through;
DESI creates files with `300` and the current app migrates them to
`300, 301, 302, 303`. DESI refuses files whose versions it doesn't know
("Newer version of DESI required"). Keystrip never modifies `meta`. Keystrip
refuses to open a file whose `kind` is not `dsi`.

`extension` holds one row per phone (DESI calls them extensions):

| column | meaning |
|---|---|
| `id` | Extension number or a template name, e.g. `118`, `X135`, `Standard`. Case-sensitive. |
| `typecode` | DESI model code: `AWX9212` (12 keys) or `AWX9224` (24 keys). Other codes exist for other phones. |
| `name` | Person or location. May be empty. |
| `modified` | Local timestamp `YYYYMMDDTHHMMSS`, e.g. `20250829T103509`. |

`field` holds one row per non-blank label, keyed by `(extension_id, field_id)`,
with `content` as RTF (section 2.4). A missing row is a blank label.

| `field_id` | meaning |
|---|---|
| 4796 | The name strip at the top of the phone. |
| `5096 + 1000 × (k − 1)` | Key k, 1-based, top to bottom down the strip. 12 keys for AWX9212 (5096…16096), 24 for AWX9224 (5096…28096). |
| 1…1024 | Reserved by DESI (comment fields). Keystrip preserves them and never creates them. |

Physical layout (confirmed from the DESI label photo and the Allworx Word
templates): the paper strip is one narrow vertical column. Each row is a
rounded "finger" cell whose open end alternates sides, odd rows opening to the
right and even rows to the left, because the phone's keys are staggered on
both sides of the strip. The name strip sits above row 1.

`selections` holds the id of the phone currently selected in the DESI UI. One
row in practice. Keystrip rewrites it to the phone selected in Keystrip when
the user saves, and leaves it alone if nothing is selected.

`graphics` holds embedded images. Keystrip never reads or writes it.

### 2.4 Label RTF

DESI writes every field with one template. Bytes are exactly:

```
{\rtf1\ansi{\fonttbl{\f0\ftnil FACE;}}{\colortbl\redR\greenG\blueB;}\f0\cf0\fsN\qA[\b][\i][\ul] TEXT}
```

- `\ftnil` is what DESI writes. It is not standard RTF (`\fnil` is). Reproduce
  it verbatim; do not "fix" it.
- `FACE` is the font name, `Arial` in every observed field.
- The colour table has exactly one entry, at index 0, and `\cf0` selects it.
  Black is `\red0\green0\blue0`.
- `N` is the font size in half-points: 18 (9 pt) is DESI's default, 16 (8 pt)
  also occurs.
- `A` is the alignment: `c` centre (every observed field), `l` left, `r` right,
  `j` justified.
- Whole-field bold, italic, and underline appear as `\b`, `\i`, `\ul` right
  after `\qA`. Inline changes within the text use `\b0`, `\i0`, `\ulnone`
  (or `\ul0`) and their counterparts.
- One space separates the last control word from `TEXT`. An empty label is
  written as `...\qc\b }` or `...\qc }` (space then brace).
- A line break inside `TEXT` is `\par ` including the trailing space. A
  trailing `\par ` before the closing brace is legal and occurs in real files.
- Escapes: `\\`, `\{`, `\}`; `\'hh` for a Windows-1252 byte; `\uN?` for other
  Unicode scalars (N is a signed 16-bit decimal, `?` is the fallback
  character, and a preceding `\ucN` sets how many fallback characters follow;
  default 1). `\tab` is a tab; `\line` is treated as a paragraph break on read
  and written as `\par `.

Examples from a real file:

```
{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Park\par 703}
{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc Andrew x118}
{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green64\blue64;}\f0\cf0\fs18\qc\b Operator\par Assistance}
{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b }
```

### 2.5 How DESI itself writes

DESI uses these statements (from the executable), and Keystrip uses the same
shapes so its writes look like DESI's:

```sql
INSERT OR REPLACE INTO field (extension_id, field_id, content) VALUES (:extension_id, :field_id, :content);
DELETE FROM field WHERE extension_id=:extension_id AND field_id=:field_id;
INSERT INTO extension (id, typecode, name, modified) VALUES (:id, :typecode, :name, :modified);
UPDATE extension SET typecode=:typecode WHERE id=:id
DELETE FROM extension WHERE id=:id;
DELETE FROM selections;
INSERT INTO selections (extension_id) VALUES (:extension_id);
```

SQLite does not enforce foreign keys unless `PRAGMA foreign_keys=ON` is set
per connection, so Keystrip never relies on the `ON DELETE CASCADE` or
`ON UPDATE CASCADE` clauses: it deletes and re-keys `field` and `selections`
rows explicitly. Keystrip never uses `INSERT OR REPLACE` on `extension`,
because with foreign keys enabled the REPLACE would cascade-delete the
phone's fields.

## 3. Architecture

Two layers. `KeystripCore` is a Swift package with no third-party
dependencies that owns the file format and is fully testable from the terminal
with `swift test`. `Keystrip` is a SwiftUI document-based app with one
multiplatform target, generated from an XcodeGen `project.yml`.

### 3.1 Repository layout

```
keystrip/
  KeystripCore/
    Package.swift
    Sources/KeystripCore/
      Model/        Phone, Label, LabelText, Run, PhoneModel, PhoneCatalog, DSIDocumentData
      RTF/          RTFTokenizer, RTFParser, RTFWriter, Windows1252
      DSI/          SQLiteDatabase (thin C-API wrapper), DSIReader, DSIWriter, DSISchema
    Tests/KeystripCoreTests/
      Fixtures/sample.dsi
      ...
  App/
    Keystrip/       SwiftUI sources, Info.plist entries, entitlements, assets
  project.yml       XcodeGen definition (generates Keystrip.xcodeproj, which is gitignored)
  Scripts/
    make-fixture.sh         builds Tests/.../Fixtures/sample.dsi from SQL with the sqlite3 CLI
    check-real-file.swift   round-trip check against a real .dsi that is never committed
    ci.sh                   the exact commands CI runs
  .github/workflows/ci.yml
  docs/superpowers/specs/, docs/superpowers/plans/
  LICENSE (MIT), README.md, .gitignore
```

Real `.dsi` files contain names of real people and are gitignored. The
proprietary DESI Windows program is never committed.

### 3.2 Toolchain

- Xcode 27, Swift 6 language mode, Swift Testing for tests.
- Deployment targets: macOS 15.0, iOS 18.0 (iPhone and iPad). Code must also
  compile with the Xcode 26 SDK because GitHub's runners may lag; anything
  newer is gated with `#available`.
- XcodeGen 2.44 or later, `supportedDestinations: [macOS, iOS, iPad]` on one
  application target. The generated project is not committed; `xcodegen
  generate` recreates it.
- Code signing is automatic with no team set in the project, so contributors
  build locally with their own account. CI builds with `CODE_SIGNING_ALLOWED=NO`.

## 4. KeystripCore

### 4.1 Model

```swift
public struct DSIDocumentData: Equatable, Sendable {
    public var meta: [String: String]        // read-only copy, never written back
    public var phones: [Phone]               // in file order (by rowid) on load
    public var selectedPhoneID: String?      // from `selections`
}

public struct Phone: Identifiable, Equatable, Sendable {
    public var id: String                    // extension.id
    public var typecode: String              // extension.typecode
    public var name: String
    public var modified: String              // DESI timestamp string, see DESITimestamp
    public var fields: [Int: Label]          // every row in `field`, including unknown ids
}

public struct Label: Equatable, Sendable {
    public var text: LabelText
    public var originalRTF: String?          // bytes as read from the file; nil for a new label
    public var isEdited: Bool { get }        // computed: false when originalRTF != nil and text == parse(originalRTF)
}

public struct LabelText: Equatable, Sendable {
    public var fontFace: String = "Arial"
    public var fontSize: Int = 18            // half-points
    public var color: RGBColor = .black
    public var alignment: TextAlignment = .center   // .left, .center, .right, .justified
    public var paragraphs: [[Run]] = [[]]    // never empty; a blank label is [[]]
}

public struct Run: Equatable, Sendable {
    public var text: String
    public var bold = false, italic = false, underline = false
}

public struct PhoneModel: Sendable {
    public let typecode: String              // "AWX9212"
    public let displayName: String           // "Allworx 9212"
    public let keyCount: Int                 // 12
    public static let nameStripFieldID = 4796
    public func fieldID(forKey k: Int) -> Int   // 5096 + 1000 * (k - 1)
    public func keyIndex(forFieldID id: Int) -> Int?
}

public enum PhoneCatalog {
    public static let known: [PhoneModel]    // AWX9212, AWX9224
    public static func model(for typecode: String) -> PhoneModel?
}

public enum DESITimestamp {
    public static func now() -> String       // "yyyyMMdd'T'HHmmss", local time
}
```

`LabelText` has two convenience conversions used by the editor:

- `plainText: String` joins run texts within a paragraph and paragraphs with
  `\n`.
- `fieldStyle: FieldStyle` (bold, italic, underline) is the style of the
  first non-empty run, or all false.
- `replacingText(_ s: String)` splits on `\n` and rebuilds every paragraph as
  one run carrying `fieldStyle`, keeping fontFace, fontSize, color, and
  alignment. `hasMixedRuns` reports whether any paragraph has runs with
  differing styles, so the UI can warn before the text is simplified.

### 4.2 RTF codec

`RTFTokenizer` produces `{`, `}`, control words (name plus optional signed
integer parameter, consuming one following space as delimiter), control
symbols (`\'hh`, `\\`, `\{`, `\}`, `\~`, `\-`, `\_`, `\*`), and text runs.

`RTFParser.parse(_ rtf: String) throws -> LabelText`:

- Requires the outer group to start with `\rtf1`. Anything else throws
  `RTFError.notRTF`.
- `{\fonttbl ...}` records font 0's face (text up to `;`). `{\colortbl ...}`
  records entries; an empty first entry (`;` immediately) means "auto" and is
  treated as black. `\cfN` selects an entry; an out-of-range index is black.
- Document-level words: `\fsN`, `\qc` `\ql` `\qr` `\qj`, `\b` `\b0`, `\i`
  `\i0`, `\ul` `\ulnone` `\ul0`, `\plain` (resets bold, italic, underline),
  `\par` and `\line` (paragraph break), `\tab`, `\ucN`, `\uN`.
- Groups other than the two tables push and pop the run style. Groups that
  start with `\*` are skipped entirely. Unknown control words are ignored.
- Adjacent runs with identical style are merged. Text is accumulated as
  Unicode; `\'hh` is decoded through a Windows-1252 table.

`RTFWriter.write(_ text: LabelText) -> String` emits the DESI template from
section 2.4:

- Field-level style is the style of the first run of the first paragraph
  (`\b`, `\i`, `\ul` in that order). Subsequent style changes are emitted
  inline as `\b`/`\b0`, `\i`/`\i0`, `\ul`/`\ulnone`, each followed by a
  space delimiter. If the text that follows a control word begins with a
  space, the writer emits two spaces so the delimiter doesn't eat it.
- Paragraphs are joined with `\par `.
- Text escaping: `\` `{` `}` are escaped; characters below 0x80 (except control
  characters) are literal; characters in Windows-1252 are `\'hh`; anything
  else is `\uN?`, with a surrogate pair written as two `\u` words for scalars
  above the BMP.

Codec invariant, enforced by tests over every field in the fixture and by
`Scripts/check-real-file.swift` over real files: for every field DESI wrote,
`RTFWriter.write(try RTFParser.parse(x)) == x`.

### 4.3 Reading

`DSIReader.read(_ data: Data) throws -> DSIDocumentData` loads the bytes into
an in-memory SQLite connection with `sqlite3_deserialize`, checks
`meta.kind == "dsi"` (else `DSIError.notADESIDatabase`), reads `extension`
ordered by rowid, all `field` rows, and `selections`. Each field's content is
parsed; if parsing throws, the label is kept with `text` empty, `originalRTF`
set, and `isEdited == false`, so it is written back untouched and the UI shows
it as unreadable rather than losing it.

### 4.4 Writing

`DSIWriter.write(_ current: DSIDocumentData, previous: DSIDocumentData, original: Data) throws -> Data`
deserializes `original`, applies the difference between `previous` and
`current` inside one transaction, and returns `sqlite3_serialize` bytes.
`original` and `previous` are the bytes and model from the last load or save,
so untouched rows, `meta`, `graphics`, and any unknown tables survive byte for
byte.

Rules, in order:

1. Phones in `previous` but not in `current` (by id): `DELETE FROM field`,
   `DELETE FROM selections`, `DELETE FROM extension` for that id.
2. Phones in `current` but not in `previous`: `INSERT INTO extension`, then
   `INSERT OR REPLACE INTO field` for every field, using `originalRTF` when
   `isEdited` is false and it is present, otherwise `RTFWriter.write(text)`.
   A phone whose id was renamed is a delete of the old id plus an insert of
   the new one (this carries unknown fields along explicitly).
3. Phones in both: `UPDATE extension SET typecode=?, name=?, modified=?` when
   any of those changed; fields present in `previous` but not `current` are
   deleted; fields whose `isEdited` is true or which are new are written with
   `INSERT OR REPLACE`. Fields with `isEdited == false` are not touched.
4. If `selectedPhoneID` differs from `previous` and is non-nil and refers to a
   phone in `current`: `DELETE FROM selections` then `INSERT INTO selections`.

The connection runs with `PRAGMA foreign_keys=ON` as a safety net; the rules
above never depend on it.

`DSIWriter.emptyDatabase() throws -> Data` creates a new file: `PRAGMA
encoding='UTF-16le'`, `PRAGMA page_size=1024`, the schema in section 2.2
verbatim, `meta` rows `kind=dsi` and `versions=300, 301, 302, 303`. The
`versions` value matches what the current DESI app produces after migrating a
new file, and is confirmed on Windows as part of the compatibility checklist.

Every write path is followed by `PRAGMA integrity_check` in tests.

### 4.5 SQLite wrapper

`SQLiteDatabase` is a small final class over the C API: open in-memory,
deserialize, serialize, `exec`, prepared statements with positional binding of
`String`, `Int`, `Data`, and `nil`, row iteration, and `SQLiteError` carrying
the SQLite message. Text is bound and read as UTF-8; SQLite converts to and
from the file's UTF-16le encoding.

## 5. The app

### 5.1 Document

- `DocumentGroup` over `KeystripDocument: ReferenceFileDocument`, an
  `@Observable` final class. The readable and writable content type is an
  imported UTType `com.desi.dsi` (`UTImportedTypeDeclarations`, conforms to
  `public.database`, extension `dsi`, description "DESI Database"). The app
  is the default handler on macOS; iOS declares
  `LSSupportsOpeningDocumentsInPlace` and `UISupportsDocumentBrowser`.
- State: `phones: [Phone]`, `selectedPhoneID: String?`, `meta`, plus private
  `originalData: Data` and `baseline: DSIDocumentData`. `snapshot` returns a
  `DSIDocumentData` value. `fileWrapper(snapshot:configuration:)` calls
  `DSIWriter.write(snapshot, previous: baseline, original: originalData)`, then
  updates `originalData` and `baseline` to the written result. A new document
  starts from `DSIWriter.emptyDatabase()`.
- Every mutation goes through a document method that registers an inverse
  with the `UndoManager` the view passes in, and stamps `modified` with
  `DESITimestamp.now()` on the affected phone: `addPhone(id:name:typecode:copyingLabelsFrom:)`,
  `deletePhone(id:)`, `duplicatePhone(id:newID:)`, `renamePhone(id:to:)`,
  `setName`, `setTypecode`, `setLabelText(phoneID:fieldID:text:)`,
  `setLabelStyle(phoneID:fieldID:change:)`. Setting a label's text to empty
  removes the field row (matching how DESI stores blanks) unless the row
  existed in the file, in which case it is written as an empty DESI label to
  keep the change visible to DESI as an edit.

### 5.2 Views

`ContentView` is a `NavigationSplitView`.

- Sidebar `PhoneListView`: a `List` of phones bound to `selectedPhoneID`,
  each row showing id, name, and model. `.searchable` over id and name. A
  sort menu: by id (using `localizedStandardCompare`, so 1 sorts before 10
  and 118 before X135) or by name. Toolbar button "New Phone". Context menu: Duplicate, Delete.
- Detail `PhoneEditorView` for the selected phone, or a
  `ContentUnavailableView` inviting the user to pick or create one. The
  editor shows a header (id, name, model) and a `StripView` centred in a
  scroll view.
- `StripView` draws the strip to proportion: a fixed strip width, equal row
  heights, the name strip as a full-width rounded cell on top, then one
  `KeyCellView` per key. Each key cell is a rounded "finger" shape whose open
  end alternates right (odd keys) and left (even keys), with a small key-cap
  marker beside the open end, exactly like the DESI label. The strip has a
  paper-white background with a soft shadow, and works in light and dark mode.
- `KeyCellView` contains a `TextField` with `axis: .vertical` bound to the
  label's plain text, using the label's alignment, font size (half-points
  converted to points), bold and italic in the font, `.underline()` when set,
  and the label colour as foreground. Focus sets `focusedFieldID`. On macOS,
  Return moves focus to the next key and Option-Return inserts a line break;
  on iOS, Return inserts a line break. Tab and Shift-Tab move between cells.
  If the label `hasMixedRuns`, a caption under the cell says "Mixed formatting
  will be simplified when edited".
- `.inspector(isPresented:)` on the detail shows `InspectorView`: a "Phone"
  section with editable ID (validated on commit: non-empty, trimmed, unique;
  invalid values show a message and revert), Name, and Model (picker over
  `PhoneCatalog.known`; an unknown typecode is shown as "Other (XYZ)" and can
  be changed to a known one). A "Label" section, enabled when a key is
  focused, with Bold, Italic, Underline toggles, a font size stepper showing
  points (8, 9, 10 …), an alignment segmented picker, and a `ColorPicker`.
  Style changes apply to the whole focused label.
- `NewPhoneSheet`: ID, Name, Model, and "Start from" (Blank or a copy of an
  existing phone's labels, which is how template phones like `Standard` are
  used). Duplicate uses the same sheet pre-filled. Delete asks for
  confirmation.
- On iPhone the split view collapses to a stack, and the inspector is a sheet
  with medium and large detents opened from a toolbar button. On iPad and Mac
  the inspector is a trailing column.

### 5.3 Commands and shortcuts

| Command | Shortcut |
|---|---|
| New Phone | ⇧⌘N |
| Duplicate Phone | ⌘D |
| Delete Phone | ⌘⌫ |
| Bold / Italic / Underline | ⌘B / ⌘I / ⌘U |
| Bigger / Smaller | ⌘+ / ⌘− |
| Align Left / Center / Right | ⇧⌘{ / ⇧⌘\| / ⇧⌘} |
| Toggle Inspector | ⌥⌘I |

Standard File and Edit menus (New, Open, Save, Duplicate, Rename, Revert,
Undo, Redo, Cut, Copy, Paste) come from `DocumentGroup`.

### 5.4 Errors

Open failures throw `LocalizedError`s with plain messages ("This file is not
a DESI database", "SQLite reported: …") which `DocumentGroup` presents. Save
failures surface the same way. Phone ID validation errors are shown inline in
the inspector and the new-phone sheet.

## 6. Testing

`KeystripCoreTests` (Swift Testing), run with
`swift test --package-path KeystripCore`:

- RTF: every field in the fixture round-trips byte-identically; parsing of
  escapes (`\'e9`, `荤?`, `\{`, `\\`), mixed inline runs, empty labels,
  trailing `\par `, `\ftnil`, an empty colortbl entry, unknown control words,
  and `\*` groups; writing of non-ASCII and leading-space-after-control-word
  cases; `plainText`, `fieldStyle`, and `replacingText`.
- Reader: the fixture loads the expected phones, fields, meta, and selection;
  unknown typecodes load; a non-SQLite blob and an SQLite file without
  `kind=dsi` throw the right errors.
- Writer: edit one label, add a phone, delete a phone, rename a phone, change
  the selection, change model. After each: reopen and check the change, check
  every other row of every table is unchanged (row-by-row comparison against
  the original), `PRAGMA encoding` is `UTF-16le`, `integrity_check` is `ok`.
  An unedited label whose RTF the writer would not reproduce byte-identically
  (a deliberately odd fixture field) is still written back unchanged.
  `emptyDatabase()` produces `sqlite_master` SQL identical to section 2.2 and
  the expected meta rows.
- Catalog: field id mapping both directions.

Fixture: `Scripts/make-fixture.sh` builds `sample.dsi` with the `sqlite3` CLI
from an SQL script (UTF-16le, page size 1024, DESI schema, `versions`
`300, 301, 302, 303`), containing: an AWX9212 phone with all 12 keys, an
AWX9212 template phone with blanks, an AWX9224 phone with 24 keys, a phone
with an unknown typecode, a comment field with id 5, a custom-colour label,
an `\fs16` label, a label with `\'e9`, a label with mixed inline runs, a
label with an odd but valid RTF that the writer would not reproduce, and one
`selections` row. All names are fictional. The generated file is committed.

`Scripts/check-real-file.swift <file.dsi>` (run locally, never on committed
data) parses and re-serializes every field in a real file and reports any
that don't round-trip.

App: CI builds the macOS app and the iOS Simulator app. No UI tests in v1.

## 7. Continuous integration

`.github/workflows/ci.yml` on push and pull request, `macos-latest`: select
the newest installed Xcode, install XcodeGen, run `Scripts/ci.sh`, which runs
`swift test --package-path KeystripCore`, `xcodegen generate`, and
`xcodebuild build` for `platform=macOS` and `generic/platform=iOS Simulator`
with `CODE_SIGNING_ALLOWED=NO`.

## 8. Windows compatibility checklist

Done by the user on a Windows machine with DESI Labeling System 3.8.x, on a
copy of a real file:

1. In Keystrip: change a label's text, add a line break, make one bold, add a
   phone copied from a template, delete a phone, rename a phone, save.
2. In DESI: open the file, confirm every change appears, open Print Preview
   for an edited phone, save from DESI.
3. In Keystrip: reopen the DESI-saved file, confirm nothing was lost.
4. Create a new file in Keystrip with one phone, save, open in DESI.

## 9. Process

The implementation plan derived from this spec is executed by Grok Build
(`grok-4.7`) one task at a time, with `swift test` and `xcodebuild` as gates
and a commit per green task. Claude reviews each commit and sends fixes back.
Before implementation, Grok reviews the spec and plan read-only and its
critique is folded in.
