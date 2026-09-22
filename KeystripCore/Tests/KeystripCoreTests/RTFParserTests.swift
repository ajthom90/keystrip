import Testing
@testable import KeystripCore

struct RTFParserTests {
    let bold = TextStyle(bold: true)
    let header = #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc"#

    @Test func parsesABoldTwoLineKey() throws {
        let text = try RTFParser.parse(header + #"\b Park\par 703}"#)
        #expect(text == LabelText(
            fontFace: "Arial", fontSize: 18, color: .black, alignment: .center, baseStyle: bold,
            paragraphs: [[TextRun("Park", style: bold)], [TextRun("703", style: bold)]]
        ))
    }

    @Test func parsesAPlainNameStrip() throws {
        let text = try RTFParser.parse(header + #" Andrew x118}"#)
        #expect(text.baseStyle == TextStyle())
        #expect(text.paragraphs == [[TextRun("Andrew x118")]])
    }

    @Test func parsesCustomColourAndSize() throws {
        let text = try RTFParser.parse(#"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green64\blue64;}\f0\cf0\fs16\qc\b Operator\par Assistance}"#)
        #expect(text.color == RGBColor(red: 0, green: 64, blue: 64))
        #expect(text.fontSize == 16)
        #expect(text.plainText == "Operator\nAssistance")
    }

    @Test func emptyLabelsKeepTheirStyle() throws {
        let emptyBold = try RTFParser.parse(header + #"\b }"#)
        #expect(emptyBold.baseStyle == bold)
        #expect(emptyBold.paragraphs == [[]])
        let emptyPlain = try RTFParser.parse(header + #" }"#)
        #expect(emptyPlain.baseStyle == TextStyle())
        #expect(emptyPlain.paragraphs == [[]])
    }

    @Test func trailingParagraphBreakMakesAnEmptyParagraph() throws {
        let text = try RTFParser.parse(header + #" Template\par }"#)
        #expect(text.paragraphs == [[TextRun("Template")], []])
        #expect(text.plainText == "Template\n")
    }

    @Test func keepsSpacesAroundLineBreaks() throws {
        let text = try RTFParser.parse(header + #"\b Incoming \par Calls}"#)
        #expect(text.plainText == "Incoming \nCalls")
    }

    @Test func decodesEscapes() throws {
        #expect(try RTFParser.parse(header + #" Caf\'e9}"#).plainText == "Café")
        #expect(try RTFParser.parse(header + #" \u256?x}"#).plainText == "Āx")
        #expect(try RTFParser.parse(header + #" \uc0\u256 x}"#).plainText == "Āx")
        #expect(try RTFParser.parse(header + #" \uc2\u256??x}"#).plainText == "Āx")
        #expect(try RTFParser.parse(header + #" \u-10179?\u-8704?}"#).plainText == "😀")
        #expect(try RTFParser.parse(header + #" \{a\} \\ R&D}"#).plainText == #"{a} \ R&D"#)
        #expect(try RTFParser.parse(header + #" a\tab b\~c\emdash d}"#).plainText == "a\tb\u{00A0}c\u{2014}d")
    }

    @Test func parsesMixedInlineRuns() throws {
        let text = try RTFParser.parse(header + #"\b Ben \b0 S\i x\i0}"#)
        #expect(text.baseStyle == bold)
        #expect(text.paragraphs == [[
            TextRun("Ben ", style: bold), TextRun("S"), TextRun("x", style: TextStyle(italic: true)),
        ]])
        #expect(text.hasMixedRuns)
    }

    @Test func underlineAndPlainWords() throws {
        let text = try RTFParser.parse(header + #"\ul a\ulnone b\ul\b c\plain d}"#)
        #expect(text.paragraphs == [[
            TextRun("a", style: TextStyle(underline: true)), TextRun("b"),
            TextRun("c", style: TextStyle(bold: true, underline: true)), TextRun("d"),
        ]])
    }

    @Test func groupsScopeTheStyle() throws {
        let text = try RTFParser.parse(header + #" a{\b b}c}"#)
        #expect(text.paragraphs == [[TextRun("a"), TextRun("b", style: bold), TextRun("c")]])
    }

    @Test func skipsIgnorableDestinationsAndUnknownWords() throws {
        let text = try RTFParser.parse(#"{\rtf1\ansi\deff0{\fonttbl{\f0\fswiss Helvetica;}}{\*\generator Riched20 10.0;}{\info{\title T}}\viewkind4\f0\fs20\kerning1\qr\b Odd}"#)
        #expect(text.fontFace == "Helvetica")
        #expect(text.fontSize == 20)
        #expect(text.alignment == .right)
        #expect(text.plainText == "Odd")
    }

    @Test func autoColourEntryIsBlack() throws {
        let red = try RTFParser.parse(#"{\rtf1{\fonttbl{\f0 Arial;}}{\colortbl;\red255\green0\blue0;}\f0\cf1 r}"#)
        #expect(red.color == RGBColor(red: 255, green: 0, blue: 0))
        let auto = try RTFParser.parse(#"{\rtf1{\fonttbl{\f0 Arial;}}{\colortbl;\red255\green0\blue0;}\f0\cf0 r}"#)
        #expect(auto.color == .black)
        let outOfRange = try RTFParser.parse(#"{\rtf1{\colortbl\red9\green9\blue9;}\cf7 r}"#)
        #expect(outOfRange.color == .black)
    }

    @Test func defaultsWhenWordsAreMissing() throws {
        let text = try RTFParser.parse(#"{\rtf1 hello}"#)
        #expect(text == LabelText(fontFace: "Arial", fontSize: 24, color: .black, alignment: .left, baseStyle: TextStyle(), paragraphs: [[TextRun("hello")]]))
    }

    @Test func lineIsAParagraphBreakAndTextAfterTheDocumentIsIgnored() throws {
        let text = try RTFParser.parse(header + #" a\line b}trailing"#)
        #expect(text.plainText == "a\nb")
    }

    @Test func rejectsNonRTF() {
        #expect(throws: RTFError.notRTF) { try RTFParser.parse("not rtf at all") }
        #expect(throws: RTFError.notRTF) { try RTFParser.parse(#"{\foo bar}"#) }
        #expect(throws: RTFError.notRTF) { try RTFParser.parse("") }
    }
}
