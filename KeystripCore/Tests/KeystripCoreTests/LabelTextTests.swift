import Foundation
import Testing
@testable import KeystripCore

struct LabelTextTests {
    let bold = TextStyle(bold: true)

    @Test func defaultsMatchDESI() {
        let text = LabelText()
        #expect(text.fontFace == "Arial")
        #expect(text.fontSize == 18)
        #expect(text.color == .black)
        #expect(text.alignment == .center)
        #expect(text.baseStyle == TextStyle())
        #expect(text.paragraphs == [[]])
        #expect(text.isBlank)
    }

    @Test func emptyParagraphListBecomesOneEmptyParagraph() {
        #expect(LabelText(paragraphs: []).paragraphs == [[]])
    }

    @Test func plainTextJoinsRunsAndParagraphs() {
        let text = LabelText(paragraphs: [
            [TextRun("Park", style: bold)],
            [TextRun("70", style: bold), TextRun("3")],
            [],
        ])
        #expect(text.plainText == "Park\n703\n")
        #expect(!text.isBlank)
    }

    @Test func hasMixedRunsComparesEveryRunToTheBaseStyle() {
        let uniform = LabelText(baseStyle: bold, paragraphs: [[TextRun("A", style: bold)], [TextRun("B", style: bold)]])
        #expect(!uniform.hasMixedRuns)
        let mixed = LabelText(baseStyle: bold, paragraphs: [[TextRun("Ben ", style: bold), TextRun("S")]])
        #expect(mixed.hasMixedRuns)
    }

    @Test func replacingTextKeepsFormattingAndUsesTheBaseStyle() {
        let original = LabelText(
            fontSize: 16, color: RGBColor(red: 0, green: 64, blue: 64), alignment: .left,
            baseStyle: bold, paragraphs: [[TextRun("old", style: bold), TextRun("x")]]
        )
        let replaced = original.replacingText("Page\r\nPhones\n")
        #expect(replaced.fontSize == 16)
        #expect(replaced.color == RGBColor(red: 0, green: 64, blue: 64))
        #expect(replaced.alignment == .left)
        #expect(replaced.baseStyle == bold)
        #expect(replaced.paragraphs == [[TextRun("Page", style: bold)], [TextRun("Phones", style: bold)], []])
    }

    @Test func replacingWithEmptyTextGivesABlankLabel() {
        let replaced = LabelText(baseStyle: bold, paragraphs: [[TextRun("x", style: bold)]]).replacingText("")
        #expect(replaced.paragraphs == [[]])
        #expect(replaced.baseStyle == bold)
    }

    @Test func formatReadsTheSizeColorAlignmentAndBaseStyle() {
        let text = LabelText(fontSize: 16, color: .black, alignment: .right, baseStyle: bold)
        #expect(text.format == LabelFormat(fontSize: 16, color: .black, alignment: .right, style: bold))
    }

    @Test func settingAStyleFlattensEveryRunToIt() {
        var text = LabelText(baseStyle: bold, paragraphs: [[TextRun("Ben ", style: bold), TextRun("S")], [TextRun("x", style: bold)]])
        var format = text.format
        format.style = TextStyle(italic: true)
        text.format = format
        #expect(text.baseStyle == TextStyle(italic: true))
        #expect(text.paragraphs == [[TextRun("Ben S", style: TextStyle(italic: true))], [TextRun("x", style: TextStyle(italic: true))]])
    }

    @Test func settingOnlyTheSizeKeepsMixedRuns() {
        let runs = [[TextRun("Ben ", style: bold), TextRun("S")]]
        var text = LabelText(baseStyle: bold, paragraphs: runs)
        var format = text.format
        format.fontSize = 20
        text.format = format
        #expect(text.fontSize == 20)
        #expect(text.paragraphs == runs)
    }

    @Test func templatesAreBoldForKeysAndPlainForTheNameStrip() {
        #expect(LabelText.template(forFieldID: 4796).baseStyle == TextStyle())
        #expect(LabelText.template(forFieldID: 5096).baseStyle == bold)
        #expect(LabelText.template(forFieldID: 28096).baseStyle == bold)
        #expect(LabelText.template(forFieldID: 5096).isBlank)
    }

    @Test func colorComponentsAreClamped() {
        #expect(RGBColor(red: -4, green: 300, blue: 12) == RGBColor(red: 0, green: 255, blue: 12))
    }

    @Test func timestampUsesDESIFormatInTheGivenTimeZone() throws {
        let date = Date(timeIntervalSince1970: 1_758_560_400)
        #expect(DESITimestamp.string(from: date, timeZone: try #require(TimeZone(identifier: "UTC"))) == "20250922T170000")
        #expect(DESITimestamp.string(from: date, timeZone: try #require(TimeZone(secondsFromGMT: -5 * 3600))) == "20250922T120000")
        #expect(DESITimestamp.now().count == 15)
    }
}
