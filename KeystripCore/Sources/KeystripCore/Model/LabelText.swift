import Foundation

public struct RGBColor: Equatable, Hashable, Sendable {
    public var red: Int
    public var green: Int
    public var blue: Int

    public init(red: Int, green: Int, blue: Int) {
        self.red = min(max(red, 0), 255)
        self.green = min(max(green, 0), 255)
        self.blue = min(max(blue, 0), 255)
    }

    public static let black = RGBColor(red: 0, green: 0, blue: 0)
}

/// RTF paragraph alignment; the raw value is the letter after `\q`.
public enum LabelAlignment: String, CaseIterable, Sendable {
    case left = "l"
    case center = "c"
    case right = "r"
    case justified = "j"
}

public struct TextStyle: Equatable, Hashable, Sendable {
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool

    public init(bold: Bool = false, italic: Bool = false, underline: Bool = false) {
        self.bold = bold
        self.italic = italic
        self.underline = underline
    }
}

public struct TextRun: Equatable, Sendable {
    public var text: String
    public var style: TextStyle

    public init(_ text: String, style: TextStyle = TextStyle()) {
        self.text = text
        self.style = style
    }
}

/// The whole-label formatting the editor exposes.
public struct LabelFormat: Equatable, Sendable {
    public var fontSize: Int
    public var color: RGBColor
    public var alignment: LabelAlignment
    public var style: TextStyle

    public init(fontSize: Int, color: RGBColor, alignment: LabelAlignment, style: TextStyle) {
        self.fontSize = fontSize
        self.color = color
        self.alignment = alignment
        self.style = style
    }
}

/// The content of one DESI label field. See spec section 4.1.
public struct LabelText: Equatable, Sendable {
    public var fontFace: String
    /// Font size in half-points (18 = 9 pt).
    public var fontSize: Int
    public var color: RGBColor
    public var alignment: LabelAlignment
    /// The style written in the RTF header; also the style of a blank label.
    public var baseStyle: TextStyle
    /// Never empty. A blank label is `[[]]`.
    public var paragraphs: [[TextRun]]

    public init(
        fontFace: String = "Arial",
        fontSize: Int = 18,
        color: RGBColor = .black,
        alignment: LabelAlignment = .center,
        baseStyle: TextStyle = TextStyle(),
        paragraphs: [[TextRun]] = [[]]
    ) {
        self.fontFace = fontFace
        self.fontSize = fontSize
        self.color = color
        self.alignment = alignment
        self.baseStyle = baseStyle
        self.paragraphs = paragraphs.isEmpty ? [[]] : paragraphs
    }

    public var plainText: String {
        paragraphs.map { $0.map(\.text).joined() }.joined(separator: "\n")
    }

    public var isBlank: Bool { plainText.isEmpty }

    public var hasMixedRuns: Bool {
        paragraphs.contains { $0.contains { $0.style != baseStyle } }
    }

    /// New text in the base style, keeping font, size, colour, and alignment.
    public func replacingText(_ text: String) -> LabelText {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var copy = self
        copy.paragraphs = normalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in line.isEmpty ? [] : [TextRun(String(line), style: baseStyle)] }
        return copy
    }

    public var format: LabelFormat {
        get { LabelFormat(fontSize: fontSize, color: color, alignment: alignment, style: baseStyle) }
        set {
            fontSize = newValue.fontSize
            color = newValue.color
            alignment = newValue.alignment
            // A size, colour, or alignment change leaves the runs (even mixed ones) alone.
            guard newValue.style != baseStyle else { return }
            baseStyle = newValue.style
            paragraphs = paragraphs.map { runs in
                let joined = runs.map(\.text).joined()
                return joined.isEmpty ? [] : [TextRun(joined, style: newValue.style)]
            }
        }
    }

    /// The formatting DESI uses for a new label: bold for keys, plain for the name strip.
    public static func template(forFieldID fieldID: Int) -> LabelText {
        LabelText(baseStyle: TextStyle(bold: fieldID != PhoneModel.nameStripFieldID))
    }
}
