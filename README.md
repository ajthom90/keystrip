# Keystrip

Keystrip is an open-source SwiftUI app for macOS, iPadOS, and iOS that edits
DESI Labeling System database files (`.dsi`) holding key labels for Allworx
9212 and 9224 desk phones. Printing stays in the free Windows DESI app.

## Not affiliated

Keystrip is not affiliated with DESI Telephone Labels, Inc. or Allworx.

## Features

- Open, edit, and save `.dsi` documents on a Mac, iPad, or iPhone.
- List phones with search and sort by id or name.
- Draw each phone's label strip: staggered finger cells for the Allworx 9224,
  and rectangular rows with clip tabs for the 9212 and unknown models.
- Edit the name strip and every key. On a Mac, Return moves to the next cell
  and Option-Return inserts a line break; on iPhone and iPad, Return inserts
  a line break. Tab and Shift-Tab move between cells on every platform.
- Format the focused label: bold, italic, underline, size, alignment, and colour.
- Add, duplicate, and delete phones. A new phone can start blank or copy
  another phone's labels.
- Inspect and change a phone's id, name, and model. Unknown models stay
  available as "Other (…)".
- Keep unreadable labels unchanged, warn when mixed formatting will be
  simplified on edit, and preserve fields the strip does not show.
- Undo and redo through the standard Edit menu.

## Building

You need Xcode 26 or later and XcodeGen:

```bash
brew install xcodegen
xcodegen generate
open Keystrip.xcodeproj
```

The default signing is ad-hoc, so the app builds and runs on a Mac or
simulator without an Apple developer team. To run on a device, create
`Config/Local.xcconfig` (gitignored). `Config/Signing.xcconfig` says:

```
// Default: ad-hoc signing, so the app builds and runs on a Mac or simulator
// without an Apple developer team. To run on a device, create
// Config/Local.xcconfig (gitignored) containing:
//   DEVELOPMENT_TEAM = ABCDE12345
//   CODE_SIGN_STYLE = Automatic
//   CODE_SIGN_IDENTITY = Apple Development
```

## Testing

`Scripts/ci.sh` runs the package tests and builds the macOS and iOS Simulator
apps. That is what continuous integration runs.

To check a real `.dsi` file on your machine:

```bash
swift run --package-path KeystripCore keystrip-check <file.dsi>
```

It prints only phone ids and counts unless given `--show`.

## Windows compatibility

Done on a Windows machine with DESI Labeling System 3.8.x, on a copy of a
real file:

1. In Keystrip: change a label's text, add a line break, make one bold, type
   a label with an accented letter (é) and one with a euro sign (€), add a
   phone copied from a template, delete a phone, rename a phone, save.
2. In DESI: open the file, confirm every change appears, open Print Preview
   for an edited phone, save from DESI.
3. In Keystrip: reopen the DESI-saved file, confirm nothing was lost.
4. Create a new file in Keystrip with one phone, save, open in DESI.

## File format

A `.dsi` file is a SQLite database in DESI's schema, with each label stored
as a small RTF subset. The byte-level description is in
[the design spec](docs/superpowers/specs/2026-09-22-keystrip-design.md).

## Privacy

Real `.dsi` files contain people's names, so never commit them. The repo's
`.gitignore` blocks them.

## License

MIT. See `LICENSE`.
