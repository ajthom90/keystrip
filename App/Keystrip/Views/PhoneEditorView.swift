import KeystripCore
import SwiftUI

/// Header and label strip for one phone. Reports the focused field through `activeFieldID`.
struct PhoneEditorView: View {
    var document: KeystripDocument
    var phone: Phone
    @Binding var activeFieldID: Int?

    @FocusState private var focusedFieldID: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ScrollView {
                StripView(document: document, phone: phone, focusedFieldID: $focusedFieldID)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(phone.id)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: focusedFieldID) { _, newValue in
            if let newValue {
                activeFieldID = newValue
            }
        }
        .onChange(of: phone.id) { _, _ in
            activeFieldID = nil
            focusedFieldID = nil
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(phone.id)
                .font(.title2.weight(.semibold))
            Text(phone.name.isEmpty ? "No name" : phone.name)
                .font(.title3)
                .foregroundStyle(phone.name.isEmpty ? .secondary : .primary)
            Text(PhoneCatalog.displayName(for: phone.typecode))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let footnote = otherFieldsFootnote {
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var otherFieldsFootnote: String? {
        let count = phone.otherFieldIDs.count
        guard count > 0 else { return nil }
        if count == 1 {
            return "1 other field is preserved but not shown."
        }
        return "\(count) other fields are preserved but not shown."
    }
}
