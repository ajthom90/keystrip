import Testing
@testable import KeystripCore

struct RTFWriterTests {
    let bold = TextStyle(bold: true)

    /// Fields exactly as DESI writes them (from a real file, names changed).
    static let desiFields: [String] = [
        #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Park\par 703}"#,
        #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc Sam x118}"#,
        #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green64\blue64;}\f0\cf0\fs18\qc\b Operator\par Assistance}"#,
        #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b }"#,
        #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc }"#,
        #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc Template\par }"#,
        #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs16\qc\b Page Phones}"#,
        #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Incoming \par Calls}"#,
        #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b R&D Lab \par Phones}"#,
        #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Waseca\par Warehouse\par Page}"#,
        #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc x150 \par P1 Lobby}"#,
    ]

    @Test(arguments: desiFields)
    func desiFieldsRoundTripByteForByte(field: String) throws {
        #expect(RTFWriter.write(try RTFParser.parse(field)) == field)
    }

    @Test func writesTheDESIHeaderForANewLabel() {
        let text = LabelText.template(forFieldID: 5096).replacingText("Page\nPhones")
        #expect(RTFWriter.write(text) == #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Page\par Phones}"#)
    }

    @Test func writesEveryHeaderStyleAndAlignment() {
        let text = LabelText(fontSize: 20, color: RGBColor(red: 255, green: 1, blue: 2), alignment: .right,
                             baseStyle: TextStyle(bold: true, italic: true, underline: true),
                             paragraphs: [[TextRun("x", style: TextStyle(bold: true, italic: true, underline: true))]])
        #expect(RTFWriter.write(text) == #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red255\green1\blue2;}\f0\cf0\fs20\qr\b\i\ul x}"#)
    }

    @Test func writesInlineStyleChanges() {
        let text = LabelText(baseStyle: bold, paragraphs: [[
            TextRun("Ben ", style: bold), TextRun("S"), TextRun("x", style: TextStyle(italic: true)), TextRun("y", style: TextStyle(underline: true)),
        ]])
        #expect(RTFWriter.write(text).hasSuffix(#"\qc\b Ben \b0 S\i x\i0\ul y}"#))
    }

    @Test func escapesSpecialAndNonASCIICharacters() {
        func body(_ s: String) -> String {
            let full = RTFWriter.write(LabelText(paragraphs: [[TextRun(s)]]))
            return String(full.dropFirst(#"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc "#.count).dropLast())
        }
        #expect(body(#"{a} \ b"#) == #"\{a\} \\ b"#)
        #expect(body("Café") == #"Caf\'e9"#)
        #expect(body("€5") == #"\'805"#)
        #expect(body("Ā") == #"\u256?"#)
        #expect(body("😀") == #"\u-10179?\u-8704?"#)
        #expect(body("a\tb") == #"a\tab b"#)
        #expect(body("a\u{7}b\u{7F}c") == "abc")
    }

    @Test func textStartingWithASpaceSurvivesTheDelimiter() throws {
        let text = LabelText(baseStyle: bold, paragraphs: [[TextRun(" x", style: bold)], [TextRun(" y", style: bold)]])
        let rtf = RTFWriter.write(text)
        #expect(rtf.hasSuffix(#"\qc\b  x\par  y}"#))
        #expect(try RTFParser.parse(rtf) == text)
    }

    @Test func skipsEmptyRunsAndKeepsEmptyParagraphs() {
        let text = LabelText(paragraphs: [[TextRun("")], [], [TextRun("z")]])
        #expect(RTFWriter.write(text).hasSuffix(#"\qc \par \par z}"#))
    }

    @Test(arguments: ["Café", "Ā and 😀", "{braces} \\ back", "tab\there", "mixed € ™ “quotes”", " lead", "trail "])
    func writtenTextParsesBackToTheSameLabel(sample: String) throws {
        let text = LabelText.template(forFieldID: 6096).replacingText(sample + "\nline two")
        #expect(try RTFParser.parse(RTFWriter.write(text)) == text)
    }
}
