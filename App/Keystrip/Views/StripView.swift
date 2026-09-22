import KeystripCore
import SwiftUI

/// How the paper strip is drawn. Derived from typecode in one place.
enum StripStyle: Equatable {
    /// AWX9224: staggered finger cells, markers beside the rounded ends.
    case fingers
    /// AWX9212 and unknown models: ruled rectangular rows, markers on the right, clip tabs.
    case ruled

    static func forTypecode(_ typecode: String) -> StripStyle {
        typecode == "AWX9224" ? .fingers : .ruled
    }
}

/// Paper strip: name strip on top, then one key cell per key in the model's style.
struct StripView: View {
    var document: KeystripDocument
    var phone: Phone
    var focusedFieldID: FocusState<Int?>.Binding

    @Environment(\.colorScheme) private var colorScheme

    private let stripWidth: CGFloat = 220
    private let markerWidth: CGFloat = 22
    private let fingerSpacing: CGFloat = 3
    private let nameStripGap: CGFloat = 6
    private let clipTabHeight: CGFloat = 12
    private let ruleHeight: CGFloat = 1

    private var stripStyle: StripStyle { .forTypecode(phone.typecode) }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            switch stripStyle {
            case .fingers:
                markerColumn(.odd)
                paper
                markerColumn(.even)
            case .ruled:
                Color.clear.frame(width: markerWidth)
                paper
                markerColumn(.all)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var paper: some View {
        VStack(spacing: 0) {
            if stripStyle == .ruled {
                ClipTab(pointingUp: true)
                    .fill(clipTabColor)
                    .frame(width: stripWidth, height: clipTabHeight)
            }
            cellStack
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(width: stripWidth)
                .background(LabelStyling.stripBackground(for: colorScheme), in: paperShape)
                .overlay(paperShape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.18), radius: 8, y: 3)
            if stripStyle == .ruled {
                ClipTab(pointingUp: false)
                    .fill(clipTabColor)
                    .frame(width: stripWidth, height: clipTabHeight)
            }
        }
    }

    private var cellStack: some View {
        VStack(spacing: rowSpacing) {
            cell(kind: .nameStrip)
                .padding(.bottom, nameExtraGap)
            ForEach(keyNumbers, id: \.self) { number in
                if stripStyle == .ruled {
                    Rectangle()
                        .fill(ruleColor)
                        .frame(height: ruleHeight)
                }
                cell(kind: .key(number))
            }
        }
    }

    private var paperShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: stripStyle == .fingers ? 10 : 2, style: .continuous)
    }

    private var rowSpacing: CGFloat {
        stripStyle == .fingers ? fingerSpacing : 0
    }

    private var nameExtraGap: CGFloat {
        stripStyle == .fingers ? nameStripGap - fingerSpacing : 0
    }

    private var clipTabColor: Color {
        switch colorScheme {
        case .dark: Color(white: 0.45)
        default: Color(white: 0.62)
        }
    }

    private var ruleColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.35 : 0.22)
    }

    private func cell(kind: KeyCellView.Kind) -> KeyCellView {
        let fieldID: Int
        let label: PhoneLabel?
        switch kind {
        case .nameStrip:
            fieldID = PhoneModel.nameStripFieldID
            label = phone.nameStrip
        case .key(let number):
            fieldID = PhoneModel.fieldID(forKey: number)
            label = phone.label(forKey: number)
        }
        return KeyCellView(
            document: document,
            phoneID: phone.id,
            kind: kind,
            label: label,
            rowHeight: rowHeight,
            stripStyle: stripStyle,
            focusedFieldID: focusedFieldID,
            onMoveFocus: { delta in moveFocus(from: fieldID, delta: delta) }
        )
    }

    private enum MarkerFilter {
        case odd, even, all

        func includes(_ number: Int) -> Bool {
            switch self {
            case .odd: !number.isMultiple(of: 2)
            case .even: number.isMultiple(of: 2)
            case .all: true
            }
        }
    }

    private func markerColumn(_ filter: MarkerFilter) -> some View {
        VStack(spacing: 0) {
            if stripStyle == .ruled {
                Color.clear.frame(width: markerWidth, height: clipTabHeight)
            }
            VStack(spacing: rowSpacing) {
                Color.clear
                    .frame(width: markerWidth, height: rowHeight)
                    .padding(.bottom, nameExtraGap)
                ForEach(keyNumbers, id: \.self) { number in
                    if stripStyle == .ruled {
                        Color.clear.frame(height: ruleHeight)
                    }
                    Group {
                        if filter.includes(number) {
                            keyCapMarker(number)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: markerWidth, height: rowHeight)
                }
            }
            .padding(.vertical, 10)
            if stripStyle == .ruled {
                Color.clear.frame(width: markerWidth, height: clipTabHeight)
            }
        }
        .accessibilityHidden(true)
    }

    private func keyCapMarker(_ number: Int) -> some View {
        Text("\(number)")
            .font(.caption2.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.quaternary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(.tertiary, lineWidth: 0.5)
            )
    }

    /// 9212 rows fit a typical Mac window; 9224 rows are a little shorter.
    private var rowHeight: CGFloat {
        phone.keyCount > 12 ? 28 : 40
    }

    private var keyNumbers: [Int] {
        phone.keyCount > 0 ? Array(1...phone.keyCount) : []
    }

    private var fieldOrder: [Int] {
        [PhoneModel.nameStripFieldID] + phone.keyFieldIDs
    }

    private var editableFieldIDs: [Int] {
        fieldOrder.filter { phone.fields[$0]?.isUnreadable != true }
    }

    private func moveFocus(from fieldID: Int, delta: Int) {
        let order = editableFieldIDs
        guard !order.isEmpty else { return }
        if let index = order.firstIndex(of: fieldID) {
            focusedFieldID.wrappedValue = order[(index + delta + order.count) % order.count]
        } else if delta > 0, let first = order.first {
            focusedFieldID.wrappedValue = first
        } else if let last = order.last {
            focusedFieldID.wrappedValue = last
        }
    }
}

/// Short trapezoid that meets the paper at full width and tapers away from it.
private struct ClipTab: Shape {
    var pointingUp: Bool

    func path(in rect: CGRect) -> Path {
        let inset = min(rect.width * 0.16, 28)
        var path = Path()
        if pointingUp {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        path.closeSubpath()
        return path
    }
}
