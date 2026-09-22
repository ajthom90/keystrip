import Testing
@testable import KeystripCore

struct RTFTokenizerTests {
    @Test func tokenizesADESILabel() throws {
        let tokens = try RTFTokenizer.tokenize(#"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc\b Park\par 703}"#)
        #expect(tokens == [
            .groupStart, .controlWord("rtf", 1), .controlWord("ansi", nil),
            .groupStart, .controlWord("fonttbl", nil),
            .groupStart, .controlWord("f", 0), .controlWord("ftnil", nil), .text("Arial;"), .groupEnd,
            .groupEnd,
            .groupStart, .controlWord("colortbl", nil),
            .controlWord("red", 0), .controlWord("green", 0), .controlWord("blue", 0), .text(";"),
            .groupEnd,
            .controlWord("f", 0), .controlWord("cf", 0), .controlWord("fs", 18), .controlWord("qc", nil),
            .controlWord("b", nil), .text("Park"), .controlWord("par", nil), .text("703"),
            .groupEnd,
        ])
    }

    @Test func onlyOneDelimiterSpaceIsConsumed() throws {
        #expect(try RTFTokenizer.tokenize(#"\b  x"#) == [.controlWord("b", nil), .text(" x")])
        #expect(try RTFTokenizer.tokenize(#"\b0 x"#) == [.controlWord("b", 0), .text("x")])
    }

    @Test func parsesNegativeParametersAndFallbackCharacters() throws {
        #expect(try RTFTokenizer.tokenize(#"\u-10179?\u-8704?"#) == [
            .controlWord("u", -10179), .text("?"), .controlWord("u", -8704), .text("?"),
        ])
        #expect(try RTFTokenizer.tokenize(#"\u256?"#) == [.controlWord("u", 256), .text("?")])
    }

    @Test func parsesHexBytesAndControlSymbols() throws {
        #expect(try RTFTokenizer.tokenize(#"Caf\'e9 \{a\} \\ \*"#) == [
            .text("Caf"), .hexByte(0xE9), .text(" "), .controlSymbol("{"), .text("a"),
            .controlSymbol("}"), .text(" "), .controlSymbol("\\"), .text(" "), .controlSymbol("*"),
        ])
        #expect(try RTFTokenizer.tokenize(#"\'C9"#) == [.hexByte(0xC9)])
    }

    @Test func rawLineBreaksAreIgnoredAndEscapedOnesArePar() throws {
        #expect(try RTFTokenizer.tokenize("a\r\nb") == [.text("ab")])
        #expect(try RTFTokenizer.tokenize("a\\\nb") == [.text("a"), .controlWord("par", nil), .text("b")])
    }

    @Test func nonASCIITextPassesThrough() throws {
        #expect(try RTFTokenizer.tokenize("Café €") == [.text("Café €")])
    }

    @Test func malformedInputThrows() {
        #expect(throws: RTFError.self) { try RTFTokenizer.tokenize("abc\\") }
        #expect(throws: RTFError.self) { try RTFTokenizer.tokenize(#"\'zz"#) }
        #expect(throws: RTFError.self) { try RTFTokenizer.tokenize(#"\'e"#) }
    }

    @Test func windows1252RoundTrips() {
        #expect(Windows1252.decode(0x41) == "A")
        #expect(Windows1252.decode(0xE9) == "é")
        #expect(Windows1252.decode(0x80) == "€")
        #expect(Windows1252.decode(0x92) == "\u{2019}")
        #expect(Windows1252.decode(0x81) == "\u{FFFD}")
        #expect(Windows1252.encode("é") == 0xE9)
        #expect(Windows1252.encode("€") == 0x80)
        #expect(Windows1252.encode("\u{2019}") == 0x92)
        #expect(Windows1252.encode("Ā") == nil)
        #expect(Windows1252.encode("\u{FFFD}") == nil)
        for byte in UInt8(0xA0)...UInt8(0xFF) {
            #expect(Windows1252.encode(Windows1252.decode(byte)) == byte)
        }
    }
}
