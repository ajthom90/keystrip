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
      Model/        Phone, PhoneLabel, LabelText, TextRun, TextStyle, PhoneModel, PhoneCatalog,
                    DSIDocumentData, DocumentEditing, PhoneSorting, DESITimestamp
      RTF/          RTFTokenizer, RTFParser, RTFWriter, Windows1252
      DSI/          SQLiteDatabase (thin C-API wrapper), DSIReader, DSIWriter, DSISchema
      Editing/      DocumentEditing, PhoneSorting
    Sources/keystrip-check/   command-line round-trip checker for real files (never committed)
    Tests/KeystripCoreTests/
      Fixtures/sample.dsi
      ...
  App/
    Keystrip/       SwiftUI sources, Info.plist entries, entitlements, assets
  project.yml       XcodeGen definition (generates Keystrip.xcodeproj, which is gitignored)
  Config/Signing.xcconfig   ad-hoc signing default, optional gitignored Local.xcconfig
  Scripts/
    fixture.sql, make-fixture.sh   build Tests/.../Fixtures/sample.dsi with the sqlite3 CLI
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
- XcodeGen 2.44 or later: one application target with `platform: auto` and
  `supportedDestinations: [iOS, macOS]`, `TARGETED_DEVICE_FAMILY` `1,2`. The generated project is not committed; `xcodegen
  generate` recreates it.
- Code signing comes from `Config/Signing.xcconfig`: ad-hoc (`CODE_SIGN_IDENTITY = -`,
  manual style, no team) so anyone can build and run on a Mac or simulator, with
  `#include? "Local.xcconfig"` so a contributor can set `DEVELOPMENT_TEAM` for
  device builds in a gitignored file. CI builds with `CODE_SIGNING_ALLOWED=NO`.
- The macOS build is sandboxed with `com.apple.security.files.user-selected.read-write`
  (entitlements applied only for `sdk=macosx*`).

## 4. KeystripCore

### 4.1 Model

Type names avoid SwiftUI's (`Label`, `TextAlignment`), because the app imports
both modules.

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
    public var fields: [Int: PhoneLabel]     // every row in `field`, including unknown ids
}

public struct PhoneLabel: Equatable, Sendable {
    public var text: LabelText
    public let originalRTF: String?          // content as read from the file; nil for a new label
    public let originalText: LabelText?      // parse of originalRTF at load time
    public let isUnreadable: Bool            // originalRTF failed to parse
    public var isEdited: Bool { get }        // originalRTF == nil || text != originalText
    public var rtfForWriting: String { get } // originalRTF when !isEdited, else RTFWriter.write(text)
}

public struct TextStyle: Equatable, Hashable, Sendable {
    public var bold = false, italic = false, underline = false
}

public struct TextRun: Equatable, Sendable {
    public var text: String
    public var style: TextStyle
}

public enum LabelAlignment: String, CaseIterable, Sendable {
    case left = "l", center = "c", right = "r", justified = "j"
}

public struct LabelText: Equatable, Sendable {
    public var fontFace: String = "Arial"
    public var fontSize: Int = 18            // half-points
    public var color: RGBColor = .black
    public var alignment: LabelAlignment = .center
    public var baseStyle: TextStyle = TextStyle()   // style written in the header, see 4.2
    public var paragraphs: [[TextRun]] = [[]]        // never empty; a blank label is [[]]
}

public struct PhoneModel: Equatable, Hashable, Sendable, Identifiable {
    public let typecode: String              // "AWX9212"
    public let displayName: String           // "Allworx 9212"
    public let keyCount: Int                 // 12
    public static let nameStripFieldID = 4796
    public static func fieldID(forKey k: Int) -> Int      // 5096 + 1000 * (k - 1)
    public static func keyIndex(forFieldID id: Int) -> Int?
}

public enum PhoneCatalog {
    public static let known: [PhoneModel]    // AWX9212, AWX9224
    public static func model(for typecode: String) -> PhoneModel?
    public static func keyCount(for phone: Phone) -> Int  // model's count, else inferred from fields
}

public enum DESITimestamp {
    public static func now() -> String       // "yyyyMMdd'T'HHmmss", local time
}
```

`baseStyle` exists because an empty label still carries a style
(`...\qc\b }` is an empty bold label), and a blank label has no runs to hold
it. The parser sets it to the style in effect at the first text character, or
at the end of the body when there is no text.

`LabelText` conveniences used by the editor:

- `plainText: String` joins run texts within a paragraph and paragraphs with
  `\n`.
- `hasMixedRuns: Bool` is true when any run's style differs from `baseStyle`.
- `replacingText(_ s: String) -> LabelText` splits on `\n` and rebuilds every
  paragraph as one run carrying `baseStyle`, keeping fontFace, fontSize, color,
  and alignment.
- `format: LabelFormat` (get and set) exposes fontSize, color, alignment, and
  style together; setting it applies the style to `baseStyle` and every run.
- `LabelText.template(forFieldID:)` is the default for a new label: Arial,
  9 pt, black, centred, bold for keys and not bold for the name strip,
  matching the real files.

Editing operations live in KeystripCore as `mutating` methods on
`DSIDocumentData` so they are unit-tested without the app (section 5.1).

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

- The header style is `baseStyle` (`\b`, `\i`, `\ul` in that order). A run
  whose style differs from the current style is preceded by inline changes
  `\b`/`\b0`, `\i`/`\i0`, `\ul`/`\ulnone`.
- Every control word the writer emits is followed by one space delimiter,
  including the last header word and `\par`, exactly as DESI does. Text that
  itself starts with a space therefore comes out as two spaces, which parses
  back correctly. The exception is `\uN?`, where the `?` fallback ends the
  word.
- Paragraphs are joined with `\par `.
- Text escaping: `\` `{` `}` are escaped; characters below 0x80 (except control
  characters) are literal; characters in Windows-1252 are `\'hh`; anything
  else is `\uN?`, with a surrogate pair written as two `\u` words for scalars
  above the BMP.

Codec invariant, enforced by tests over every field in the fixture and by
`keystrip-check` over real files: for every field DESI wrote,
`RTFWriter.write(try RTFParser.parse(x)) == x`.

### 4.3 Reading

`DSIReader.read(_ data: Data) throws -> DSIDocumentData` loads the bytes into
an in-memory SQLite connection with `sqlite3_deserialize`, checks
`meta.kind == "dsi"` (else `DSIError.notADESIDatabase`), reads `extension`
ordered by rowid, all `field` rows, and `selections`. Each field's content is
parsed; if parsing throws, the label is kept with `isUnreadable == true`,
`text` and `originalText` both empty, and `originalRTF` set, so `isEdited` is
false and it is written back untouched. The UI shows it as read-only
"unreadable label, kept as is" rather than losing it. Non-SQLite data, an
empty file, or a database without `meta.kind = 'dsi'` throws
`DSIError.notADESIDatabase`.

### 4.4 Writing

`DSIWriter.write(_ current: DSIDocumentData, previous: DSIDocumentData, original: Data) throws -> Data`
deserializes `original`, applies the difference between `previous` and
`current` inside one transaction, and returns `sqlite3_serialize` bytes.
`original` and `previous` are the bytes and the model from when the document
was opened. They never change while it is open: every save applies all edits
since opening to the original bytes, which is correct no matter how many
saves happen and needs no state updated from the save thread. Untouched rows,
`meta`, `graphics`, and any unknown tables survive byte for byte.

Rules, in order:

1. If `current` has two phones with the same id, throw
   `DSIError.duplicatePhoneID` before writing anything.
2. Phones in `previous` but not in `current` (by id): `DELETE FROM field`,
   `DELETE FROM selections`, `DELETE FROM extension` for that id. A phone whose
   id was renamed is a delete of the old id plus an insert of the new one,
   which carries unknown fields along explicitly.
3. Phones in `current` but not in `previous`: `INSERT INTO extension`, then
   `INSERT OR REPLACE INTO field` with `rtfForWriting` for every field.
4. Phones in both: `UPDATE extension SET typecode=?, name=?, modified=? WHERE id=?`
   when any of those changed. For each field id in either version: absent in
   `current` means `DELETE`; different from `previous` (by value) means
   `INSERT OR REPLACE` with `rtfForWriting`; equal means untouched. A label
   edited and then changed back compares equal to its original text, so
   `rtfForWriting` returns the original bytes.
5. If `selectedPhoneID` differs from `previous` and is non-nil and refers to a
   phone in `current`: `DELETE FROM selections` then `INSERT INTO selections`.

The connection runs with `PRAGMA foreign_keys=ON` as a safety net; the rules
above never depend on it.

`DSIWriter.emptyDatabase() throws -> Data` creates a new file: `PRAGMA
encoding='UTF-16le'`, `PRAGMA page_size=1024`, the schema in section 2.2
verbatim in the same order as a DESI file's `sqlite_master` (meta, extension,
field, selections, graphics, then the `field__field_id` and
`extension__typecode` indexes), `meta` rows `kind=dsi` and `versions=300, 301, 302, 303`. The
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

- `DocumentGroup` over `KeystripDocument: ReferenceFileDocument`. The readable
  and writable content type is an imported UTType `com.desi.dsi`
  (`UTImportedTypeDeclarations`, conforms to `public.database` and
  `public.data`, extension `dsi`, description "DESI Database"), declared as an
  Editor document type. iOS also declares `LSSupportsOpeningDocumentsInPlace`
  and `UISupportsDocumentBrowser`.
- Concurrency (verified with Xcode 27 in Swift 6 mode): `ReferenceFileDocument`
  is `Sendable` with nonisolated requirements, and a `@MainActor @Observable`
  class cannot satisfy them. The document is therefore
  `@Observable final class KeystripDocument: ReferenceFileDocument, @unchecked Sendable`.
  Its observable `data: DSIDocumentData` is read by views and mutated only by
  `@MainActor` methods. Each mutation also stores a copy in a
  `Mutex<DSIDocumentData>` (Synchronization framework), and the nonisolated
  `snapshot(contentType:)` reads that copy, so saving is safe from any thread.
  `original: Data` and `baseline: DSIDocumentData` are `let` constants set at
  open. `fileWrapper(snapshot:configuration:)` is a pure function of the
  snapshot: `DSIWriter.write(snapshot.current, previous: snapshot.baseline, original: snapshot.original)`.
  A new document starts from `DSIWriter.emptyDatabase()`.
- Editing logic lives in KeystripCore as `mutating` methods on
  `DSIDocumentData`, each taking `now: String = DESITimestamp.now()` and
  stamping `modified` on the affected phone:
  `addPhone(id:name:typecode:copyingFrom:includeNameStrip:now:)`,
  `deletePhone(id:)`, `renamePhone(id:to:now:)`, `setName(_:phoneID:now:)`,
  `setTypecode(_:phoneID:now:)`, `setLabelText(_:phoneID:fieldID:now:)`,
  `updateLabelFormat(phoneID:fieldID:now:_:)`. They throw `EditError`
  (`emptyPhoneID`, `duplicatePhoneID`, `noSuchPhone`). Copying from a phone
  copies each label's `rtfForWriting` byte for byte; New Phone "start from a
  template" skips the name strip and Duplicate includes it. A no-op edit (same
  text) changes nothing and does not stamp `modified`.
- Blank labels: clearing the text of a label that exists in the file keeps
  the row as an empty label with its style, like DESI's own `...\qc\b }` rows.
  Clearing a label created in this session removes it. Typing into a blank
  key creates a label from `LabelText.template(forFieldID:)`.
- Undo: the document's `@MainActor` wrapper for each edit captures `phones`
  before the change, applies the core method, and registers an undo with the
  view's `UndoManager` that restores the captured array (and registers the
  matching redo). Registering undo is also what marks the document dirty.
  Selection changes are not undoable and don't dirty the document; the current
  selection is written to `selections` on the next real save.

### 5.2 Views

`ContentView` is a `NavigationSplitView`.

- Sidebar `PhoneListView`: a `List` of phones bound to `selectedPhoneID`,
  each row showing id, name, and model. `.searchable` over id and name. A
  sort menu: by id (using `localizedStandardCompare`, so 1 sorts before 10
  and 118 before X135) or by name. Toolbar button "New Phone". Context menu: Duplicate, Delete.
- Detail `PhoneEditorView` for the selected phone, or a
  `ContentUnavailableView` inviting the user to pick or create one. The
  editor shows a header (id, name, model) and a `StripView` centred in a
  scroll view. For an unknown typecode the key count is inferred from the
  highest key field present. A footnote lists how many other fields (comment
  fields, keys beyond the current model) are preserved but not shown.
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
| Delete Phone | none (⌫ in the sidebar on macOS), so it can't fire while typing |
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

- RTF: every field in the fixture round-trips byte-identically, including
  empty labels (`\qc\b }` and `\qc }`); parsing of
  escapes (`\'e9`, `\u256?` (Ā), `\u-10179?\u-8704?`, `\{`, `\\`), mixed inline runs, empty labels,
  trailing `\par `, `\ftnil`, an empty colortbl entry, unknown control words,
  and `\*` groups; writing of non-ASCII and leading-space-after-control-word
  cases; `plainText`, `hasMixedRuns`, `replacingText`, `format`, and `template`.
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
- Catalog: field id mapping both directions; key count inference.
- Editing: every `DSIDocumentData` mutation, its validation errors, `modified`
  stamping, no-op detection, blank-label rules, copy-from byte identity, and
  sorting and search (`localizedStandardCompare`).

Fixture: `Scripts/make-fixture.sh` builds `sample.dsi` with the `sqlite3` CLI
from an SQL script (UTF-16le, page size 1024, DESI schema, `versions`
`300, 301, 302, 303`), containing: an AWX9212 phone with all 12 keys, an
AWX9212 template phone with blanks, an AWX9224 phone with 24 keys, a phone
with an unknown typecode, a comment field with id 5, a custom-colour label,
an `\fs16` label, a label with `\'e9`, a label with mixed inline runs, a
label with an odd but valid RTF that the writer would not reproduce, and one
`selections` row. All names are fictional. The generated file is committed.

`swift run --package-path KeystripCore keystrip-check [--show] <file.dsi>`
(run locally on real files, which are never committed) parses and
re-serializes every field, checks that a no-op save is byte-identical, and
reports failures by phone and field id; `--show` adds label contents.

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

1. In Keystrip: change a label's text, add a line break, make one bold, type
   a label with an accented letter (é) and one with a euro sign (€), add a
   phone copied from a template, delete a phone, rename a phone, save.
2. In DESI: open the file, confirm every change appears, open Print Preview
   for an edited phone, save from DESI.
3. In Keystrip: reopen the DESI-saved file, confirm nothing was lost.
4. Create a new file in Keystrip with one phone, save, open in DESI.

## 9. Process

The implementation plan derived from this spec is executed by Grok Build one
task at a time, with `swift test` and `xcodebuild` as gates and a commit per
green task. Each task is run twice in parallel, by `grok-4.6` and `grok-4.7`
(both at high reasoning effort) in separate git worktrees on separate
branches, with token usage and cost recorded per run. Claude reviews both
results for each task, picks the better one to merge into `main`, sends
fixes back to that model when needed, and reports which model produced
better code. Before implementation, Grok reviews the spec and plan read-only
and its critique is folded in.
