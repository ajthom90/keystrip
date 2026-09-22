import KeystripCore
import SwiftUI

/// Paper strip: name strip on top, then one finger-shaped key cell per key.
struct StripView: View {
    var document: KeystripDocument
    var phone: Phone
    var focusedFieldID: FocusState<Int?>.Binding

    @Environment(\.colorScheme) private var colorScheme

    private let stripWidth: CGFloat = 220
    private let markerWidth: CGFloat = 22
    private let stripSpacing: CGFloat = 3
    private let nameStripGap: CGFloat = 6

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            markerColumn(odd: true)
            paper
            markerColumn(odd: false)
        }
        .accessibilityElement(children: .contain)
    }

    private var paper: some View {
        VStack(spacing: stripSpacing) {
            cell(kind: .nameStrip)
                .padding(.bottom, nameStripGap - stripSpacing)
            ForEach(keyNumbers, id: \.self) { number in
                cell(kind: .key(number))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(width: stripWidth)
        .background(LabelStyling.stripBackground(for: colorScheme), in: paperShape)
        .overlay(paperShape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.18), radius: 8, y: 3)
    }

    private var paperShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
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
            focusedFieldID: focusedFieldID,
            onMoveFocus: { delta in moveFocus(from: fieldID, delta: delta) }
        )
    }

    private func markerColumn(odd: Bool) -> some View {
        VStack(spacing: stripSpacing) {
            Color.clear
                .frame(width: markerWidth, height: rowHeight)
                .padding(.bottom, nameStripGap - stripSpacing)
            ForEach(keyNumbers, id: \.self) { number in
                Group {
                    if (number.isMultiple(of: 2) == false) == odd {
                        keyCapMarker(number)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: markerWidth, height: rowHeight)
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
