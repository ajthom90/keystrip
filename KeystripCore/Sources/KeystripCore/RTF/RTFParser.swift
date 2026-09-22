import Foundation

public enum RTFParser {
    public static func parse(_ rtf: String) throws -> LabelText {
        let tokens = try RTFTokenizer.tokenize(rtf)
        guard tokens.count >= 2, tokens[0] == .groupStart,
              case .controlWord("rtf", _) = tokens[1]
        else { throw RTFError.notRTF }
        var state = ParserState()
        state.run(tokens)
        return state.result()
    }
}

private enum Destination {
    case body
    case fontTable
    case colorTable
    case skip
}

private struct Group {
    var destination: Destination
    var style: TextStyle
    var fallbackCount: Int
}

private struct ParserState {
    private static let skipDestinations: Set<String> = [
        "stylesheet", "info", "pict", "header", "footer", "headerl", "headerr",
        "footerl", "footerr", "listtable", "listoverridetable", "generator",
        "themedata", "colorschememapping", "latentstyles", "datastore",
        "xmlnstbl", "rsidtbl", "mmathPr",
    ]

    private static let specialCharacters: [String: Unicode.Scalar] = [
        "emdash": "\u{2014}",
        "endash": "\u{2013}",
        "lquote": "\u{2018}",
        "rquote": "\u{2019}",
        "ldblquote": "\u{201C}",
        "rdblquote": "\u{201D}",
        "bullet": "\u{2022}",
    ]

    private var stack: [Group] = []
    private var awaitingFirstToken = false
    private var stopped = false
    private var paragraphs: [[TextRun]] = [[]]
    private var capturedBaseStyle: TextStyle?
    private var fontSize = 24
    private var alignment: LabelAlignment = .left
    private var fonts: [Int: String] = [:]
    private var colors: [RGBColor?] = []
    private var selectedFont: Int?
    private var selectedColor: Int?
    private var skipRemaining = 0
    private var pendingHighSurrogate: UInt16?
    private var definingFont: Int?
    private var fontName = ""
    private var colorRed: Int?
    private var colorGreen: Int?
    private var colorBlue: Int?

    mutating func run(_ tokens: [RTFToken]) {
        for token in tokens {
            if stopped { break }
            handle(token)
        }
    }

    func result() -> LabelText {
        var copy = self
        copy.flushPendingSurrogate()
        let base = copy.capturedBaseStyle ?? copy.stack.last?.style ?? TextStyle()
        let face = copy.selectedFont.flatMap { copy.fonts[$0] } ?? "Arial"
        return LabelText(
            fontFace: face,
            fontSize: copy.fontSize,
            color: copy.resolveColor(),
            alignment: copy.alignment,
            baseStyle: base,
            paragraphs: copy.paragraphs
        )
    }

    private mutating func handle(_ token: RTFToken) {
        switch token {
        case .groupStart:
            skipRemaining = 0
            if let top = stack.last {
                stack.append(top)
            } else {
                stack.append(Group(destination: .body, style: TextStyle(), fallbackCount: 1))
            }
            awaitingFirstToken = true
            return
        case .groupEnd:
            skipRemaining = 0
            awaitingFirstToken = false
            if stack.last?.destination == .fontTable {
                commitFontName()
            }
            let closed = stack.popLast()
            if stack.isEmpty {
                if capturedBaseStyle == nil {
                    capturedBaseStyle = closed?.style ?? TextStyle()
                }
                stopped = true
            }
            return
        default:
            break
        }

        if awaitingFirstToken {
            awaitingFirstToken = false
            if case .controlSymbol("*") = token {
                stack[stack.count - 1].destination = .skip
                return
            }
            if case .controlWord(let name, _) = token, let destination = destination(for: name) {
                stack[stack.count - 1].destination = destination
                return
            }
        }

        switch stack.last?.destination ?? .body {
        case .skip:
            break
        case .fontTable:
            handleFontTable(token)
        case .colorTable:
            handleColorTable(token)
        case .body:
            handleBody(token)
        }
    }

    private func destination(for name: String) -> Destination? {
        switch name {
        case "fonttbl": .fontTable
        case "colortbl": .colorTable
        case let other where Self.skipDestinations.contains(other): .skip
        default: nil
        }
    }

    private mutating func handleFontTable(_ token: RTFToken) {
        switch token {
        case .controlWord("f", let parameter):
            commitFontName()
            definingFont = parameter
        case .text(let text):
            for scalar in text.unicodeScalars {
                if scalar == ";" {
                    commitFontName()
                } else {
                    fontName.unicodeScalars.append(scalar)
                }
            }
        case .hexByte(let byte):
            fontName.unicodeScalars.append(Windows1252.decode(byte))
        default:
            break
        }
    }

    private mutating func commitFontName() {
        if let definingFont {
            fonts[definingFont] = fontName.trimmingCharacters(in: .whitespaces)
        }
        definingFont = nil
        fontName = ""
    }

    private mutating func handleColorTable(_ token: RTFToken) {
        switch token {
        case .controlWord("red", let parameter):
            colorRed = parameter ?? 0
        case .controlWord("green", let parameter):
            colorGreen = parameter ?? 0
        case .controlWord("blue", let parameter):
            colorBlue = parameter ?? 0
        case .text(let text):
            for scalar in text.unicodeScalars where scalar == ";" {
                commitColor()
            }
        default:
            break
        }
    }

    private mutating func commitColor() {
        if colorRed == nil, colorGreen == nil, colorBlue == nil {
            colors.append(nil)
        } else {
            colors.append(RGBColor(red: colorRed ?? 0, green: colorGreen ?? 0, blue: colorBlue ?? 0))
        }
        colorRed = nil
        colorGreen = nil
        colorBlue = nil
    }

    private mutating func handleBody(_ token: RTFToken) {
        switch token {
        case .controlWord(let name, let parameter):
            handleWord(name, parameter)
        case .controlSymbol(let symbol):
            handleSymbol(symbol)
        case .hexByte(let byte):
            consumeOrEmit(Windows1252.decode(byte))
        case .text(let text):
            for scalar in text.unicodeScalars {
                consumeOrEmit(scalar)
            }
        case .groupStart, .groupEnd:
            break
        }
    }

    private mutating func handleWord(_ name: String, _ parameter: Int?) {
        switch name {
        case "f":
            selectedFont = parameter
        case "cf":
            selectedColor = parameter
        case "fs":
            if let parameter, parameter > 0 { fontSize = parameter }
        case "ql":
            alignment = .left
        case "qc":
            alignment = .center
        case "qr":
            alignment = .right
        case "qj":
            alignment = .justified
        case "pard":
            alignment = .left
        case "b":
            mutateStyle { $0.bold = parameter != 0 }
        case "i":
            mutateStyle { $0.italic = parameter != 0 }
        case "ul":
            mutateStyle { $0.underline = parameter != 0 }
        case "ulnone":
            mutateStyle { $0.underline = false }
        case "plain":
            mutateStyle { $0 = TextStyle() }
        case "par", "line":
            newParagraph()
        case "tab":
            emit("\t")
        case "uc":
            if !stack.isEmpty {
                stack[stack.count - 1].fallbackCount = parameter ?? 1
            }
        case "u":
            if let parameter { emitUnicode(parameter) }
        default:
            if let scalar = Self.specialCharacters[name] {
                emit(scalar)
            }
        }
    }

    private mutating func handleSymbol(_ symbol: Character) {
        switch symbol {
        case "\\", "{", "}":
            consumeOrEmit(symbol.unicodeScalars.first!)
        case "~":
            consumeOrEmit("\u{00A0}")
        case "_":
            consumeOrEmit("\u{2011}")
        default:
            break
        }
    }

    private mutating func consumeOrEmit(_ scalar: Unicode.Scalar) {
        if skipRemaining > 0 {
            skipRemaining -= 1
            return
        }
        emit(scalar)
    }

    private mutating func emit(_ scalar: Unicode.Scalar) {
        flushPendingSurrogate()
        if capturedBaseStyle == nil {
            capturedBaseStyle = stack.last?.style ?? TextStyle()
        }
        let style = stack.last?.style ?? TextStyle()
        let character = String(scalar)
        if paragraphs.isEmpty {
            paragraphs = [[]]
        }
        var paragraph = paragraphs[paragraphs.count - 1]
        if let last = paragraph.last, last.style == style {
            paragraph[paragraph.count - 1].text += character
        } else {
            paragraph.append(TextRun(character, style: style))
        }
        paragraphs[paragraphs.count - 1] = paragraph
    }

    private mutating func emitUnicode(_ value: Int) {
        var unitValue = value
        if unitValue < 0 { unitValue += 65536 }
        let unit = UInt16(truncatingIfNeeded: unitValue)
        if let high = pendingHighSurrogate {
            pendingHighSurrogate = nil
            if (0xDC00...0xDFFF).contains(unit) {
                emit(combinedScalar(high: high, low: unit))
            } else {
                emit("\u{FFFD}")
                acceptUTF16Unit(unit)
            }
        } else {
            acceptUTF16Unit(unit)
        }
        skipRemaining = stack.last?.fallbackCount ?? 1
    }

    private mutating func acceptUTF16Unit(_ unit: UInt16) {
        if (0xD800...0xDBFF).contains(unit) {
            pendingHighSurrogate = unit
        } else if (0xDC00...0xDFFF).contains(unit) {
            emit("\u{FFFD}")
        } else if let scalar = Unicode.Scalar(UInt32(unit)) {
            emit(scalar)
        } else {
            emit("\u{FFFD}")
        }
    }

    private func combinedScalar(high: UInt16, low: UInt16) -> Unicode.Scalar {
        let value = 0x10000 + (UInt32(high) - 0xD800) * 0x400 + (UInt32(low) - 0xDC00)
        return Unicode.Scalar(value) ?? "\u{FFFD}"
    }

    private mutating func flushPendingSurrogate() {
        guard pendingHighSurrogate != nil else { return }
        pendingHighSurrogate = nil
        emit("\u{FFFD}")
    }

    private mutating func newParagraph() {
        flushPendingSurrogate()
        paragraphs.append([])
    }

    private mutating func mutateStyle(_ body: (inout TextStyle) -> Void) {
        guard !stack.isEmpty else { return }
        body(&stack[stack.count - 1].style)
    }

    private func resolveColor() -> RGBColor {
        guard let selectedColor, colors.indices.contains(selectedColor), let color = colors[selectedColor] else {
            return .black
        }
        return color
    }
}
