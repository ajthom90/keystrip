import KeystripCore
import SwiftUI

/// Font, colour, and alignment conversions from a DESI label to SwiftUI.
enum LabelStyling {
    /// Multiplier from printed point size to on-screen point size.
    static let screenScale: CGFloat = 1.5

    static func pointSize(forHalfPoints halfPoints: Int) -> CGFloat {
        CGFloat(max(halfPoints, 1)) / 2 * screenScale
    }

    static func font(for text: LabelText) -> Font {
        var font = Font.custom(text.fontFace, size: pointSize(forHalfPoints: text.fontSize))
        if text.baseStyle.bold { font = font.bold() }
        if text.baseStyle.italic { font = font.italic() }
        return font
    }

    static func color(for rgb: KeystripCore.RGBColor) -> Color {
        Color(
            red: Double(rgb.red) / 255,
            green: Double(rgb.green) / 255,
            blue: Double(rgb.blue) / 255
        )
    }

    /// Label colour adjusted so near-black DESI ink stays readable on a dark strip.
    static func foreground(for rgb: KeystripCore.RGBColor, colorScheme: ColorScheme) -> Color {
        guard colorScheme == .dark else { return color(for: rgb) }
        let red = Double(rgb.red) / 255
        let green = Double(rgb.green) / 255
        let blue = Double(rgb.blue) / 255
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        guard luminance < 0.45 else { return color(for: rgb) }
        let lift = 0.82
        return Color(
            red: red + lift * (1 - red),
            green: green + lift * (1 - green),
            blue: blue + lift * (1 - blue)
        )
    }

    /// SwiftUI has no justified `TextAlignment`; DESI `\qj` displays as leading in the field.
    static func textAlignment(for alignment: LabelAlignment) -> TextAlignment {
        switch alignment {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        case .justified: .leading
        }
    }

    static func stripBackground(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            Color(red: 0.22, green: 0.21, blue: 0.20)
        default:
            Color(red: 0.98, green: 0.96, blue: 0.91)
        }
    }
}

extension View {
    func labelStyling(_ text: LabelText, colorScheme: ColorScheme) -> some View {
        font(LabelStyling.font(for: text))
            .foregroundStyle(LabelStyling.foreground(for: text.color, colorScheme: colorScheme))
            .multilineTextAlignment(LabelStyling.textAlignment(for: text.alignment))
            .underline(text.baseStyle.underline)
    }
}
