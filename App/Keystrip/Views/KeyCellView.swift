import KeystripCore
import SwiftUI

/// One name-strip or key cell: outline, text field, and mixed-formatting caption.
struct KeyCellView: View {
    enum Kind: Equatable {
        case nameStrip
        case key(Int)
    }

    var document: KeystripDocument
    var phoneID: String
    var kind: Kind
    var label: PhoneLabel?
    var rowHeight: CGFloat
    var stripStyle: StripStyle
    var focusedFieldID: FocusState<Int?>.Binding
    var onMoveFocus: (Int) -> Void

    @Environment(\.undoManager) private var undoManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 2) {
            cellContent
                .frame(maxWidth: .infinity, minHeight: textAreaHeight, maxHeight: .infinity)
            if showsMixedCaption {
                Text("Mixed formatting will be simplified when edited")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 3)
        .frame(height: rowHeight)
        .background { outlineStroke }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var cellContent: some View {
        if label?.isUnreadable == true {
            Text("Unreadable label, kept as is")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(accessibilityName)
        } else {
            TextField("", text: textBinding, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .labelStyling(displayText, colorScheme: colorScheme)
                .focused(focusedFieldID, equals: fieldID)
                .accessibilityLabel(accessibilityName)
                .onKeyPress(keys: [.tab], phases: .down) { press in
                    onMoveFocus(press.modifiers.contains(.shift) ? -1 : 1)
                    return .handled
                }
                #if os(macOS)
                .onKeyPress(keys: [.return], phases: .down) { press in
                    if press.modifiers.contains(.option) { return .ignored }
                    onMoveFocus(1)
                    return .handled
                }
                #endif
        }
    }

    @ViewBuilder
    private var outlineStroke: some View {
        switch stripStyle {
        case .ruled:
            EmptyView()
        case .fingers:
            switch kind {
            case .nameStrip:
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(outlineColor, lineWidth: 1.25)
            case .key(let number):
                FingerShape(roundedOnLeading: number.isMultiple(of: 2) == false)
                    .stroke(outlineColor, lineWidth: 1.25)
            }
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { label?.text.plainText ?? "" },
            set: { document.setLabelText($0, phoneID: phoneID, fieldID: fieldID, undoManager: undoManager) }
        )
    }

    private var fieldID: Int {
        switch kind {
        case .nameStrip: PhoneModel.nameStripFieldID
        case .key(let number): PhoneModel.fieldID(forKey: number)
        }
    }

    private var displayText: LabelText {
        label?.text ?? LabelText.template(forFieldID: fieldID)
    }

    private var showsMixedCaption: Bool {
        label?.isUnreadable != true && (label?.text.hasMixedRuns ?? false)
    }

    private var textAreaHeight: CGFloat {
        showsMixedCaption ? max(rowHeight - 22, 16) : rowHeight - 8
    }

    private var horizontalPadding: CGFloat {
        switch (stripStyle, kind) {
        case (.fingers, .key): 14
        default: 10
        }
    }

    private var outlineColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.45 : 0.35)
    }

    private var accessibilityName: String {
        let raw = (label?.text.plainText ?? "")
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
        switch kind {
        case .nameStrip:
            return raw.isEmpty ? "Name Strip" : "Name Strip, \(raw)"
        case .key(let number):
            if label?.isUnreadable == true {
                return "Key \(number), Unreadable label, kept as is"
            }
            return raw.isEmpty ? "Key \(number)" : "Key \(number), \(raw)"
        }
    }
}

/// Rounded on one end, nearly square on the other, matching a DESI key finger.
private struct FingerShape: Shape {
    /// Odd keys round on the leading side (open end on the right).
    var roundedOnLeading: Bool

    func path(in rect: CGRect) -> Path {
        let fingerRadius = min(rect.height / 2, rect.width / 3)
        let openRadius = min(3, fingerRadius / 4)
        return UnevenRoundedRectangle(
            topLeadingRadius: roundedOnLeading ? fingerRadius : openRadius,
            bottomLeadingRadius: roundedOnLeading ? fingerRadius : openRadius,
            bottomTrailingRadius: roundedOnLeading ? openRadius : fingerRadius,
            topTrailingRadius: roundedOnLeading ? openRadius : fingerRadius,
            style: .continuous
        ).path(in: rect)
    }
}
