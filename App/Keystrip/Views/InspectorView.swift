import KeystripCore
import SwiftUI

/// Phone identity and formatting for the focused label.
struct InspectorView: View {
    var document: KeystripDocument
    var phone: Phone
    var activeFieldID: Int?
    var undoManager: UndoManager?

    private static let minimumPointSize = 6.0
    private static let maximumPointSize = 24.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Phone") {
                    PhoneIDEditor(document: document, phoneID: phone.id, undoManager: undoManager)
                    TextField("Name", text: nameBinding)
                    Picker("Model", selection: typecodeBinding) {
                        ForEach(modelChoices) { model in
                            Text(model.displayName).tag(model.typecode)
                        }
                    }
                }
                Section {
                    Group {
                        if let fieldID = activeFieldID {
                            labelControls(fieldID: fieldID)
                        }
                    }
                    .disabled(!isLabelSectionEnabled)
                    if let unavailableReason {
                        Text(unavailableReason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(labelSectionTitle)
                }
            }
            .navigationTitle("Inspector")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { phone.name },
            set: { document.setName($0, phoneID: phone.id, undoManager: undoManager) }
        )
    }

    private var typecodeBinding: Binding<String> {
        Binding(
            get: { phone.typecode },
            set: { document.setTypecode($0, phoneID: phone.id, undoManager: undoManager) }
        )
    }

    private var modelChoices: [PhoneModel] {
        guard PhoneCatalog.model(for: phone.typecode) == nil else { return PhoneCatalog.known }
        return PhoneCatalog.known + [
            PhoneModel(
                typecode: phone.typecode,
                displayName: PhoneCatalog.displayName(for: phone.typecode),
                keyCount: phone.keyCount
            ),
        ]
    }

    private var labelSectionTitle: String {
        guard let fieldID = activeFieldID else { return "Label" }
        if fieldID == PhoneModel.nameStripFieldID { return "Name Strip" }
        if let key = PhoneModel.keyIndex(forFieldID: fieldID) { return "Key \(key)" }
        return "Label"
    }

    private var isLabelSectionEnabled: Bool {
        guard let fieldID = activeFieldID else { return false }
        return phone.fields[fieldID]?.isUnreadable != true
    }

    private var unavailableReason: String? {
        guard !isLabelSectionEnabled else { return nil }
        if activeFieldID == nil {
            return "Select a label on the strip to format it."
        }
        return "Unreadable label, kept as is"
    }

    @ViewBuilder
    private func labelControls(fieldID: Int) -> some View {
        Toggle("Bold", isOn: styleBinding(fieldID, \.bold))
        Toggle("Italic", isOn: styleBinding(fieldID, \.italic))
        Toggle("Underline", isOn: styleBinding(fieldID, \.underline))
        Stepper(value: pointSizeBinding(fieldID), in: pointRange(fieldID), step: 1) {
            LabeledContent("Size", value: pointsText(fieldID))
        }
        Picker("Alignment", selection: alignmentBinding(fieldID)) {
            ForEach(LabelAlignment.allCases, id: \.self) { alignment in
                Image(systemName: alignmentSymbol(alignment))
                    .accessibilityLabel(alignmentName(alignment))
                    .tag(alignment)
            }
        }
        .pickerStyle(.segmented)
        ColorPicker("Color", selection: colorBinding(fieldID), supportsOpacity: false)
    }

    private func format(for fieldID: Int) -> LabelFormat {
        if let label = phone.fields[fieldID], !label.isUnreadable {
            return label.text.format
        }
        return LabelText.template(forFieldID: fieldID).format
    }

    private func styleBinding(_ fieldID: Int, _ keyPath: WritableKeyPath<TextStyle, Bool>) -> Binding<Bool> {
        Binding(
            get: { format(for: fieldID).style[keyPath: keyPath] },
            set: { newValue in
                guard isLabelSectionEnabled else { return }
                document.updateLabelFormat(phoneID: phone.id, fieldID: fieldID, undoManager: undoManager) {
                    $0.style[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func pointSizeBinding(_ fieldID: Int) -> Binding<Double> {
        Binding(
            get: { Double(format(for: fieldID).fontSize) / 2 },
            set: { newPoints in
                let current = format(for: fieldID).fontSize
                let half = storedHalfPoints(current: current, proposedPoints: newPoints)
                guard half != current else { return }
                document.updateLabelFormat(phoneID: phone.id, fieldID: fieldID, undoManager: undoManager) {
                    $0.fontSize = half
                }
            }
        )
    }

    /// Step toward 6...24 pt. Sizes already outside that window move one point closer instead of jumping.
    private func storedHalfPoints(current: Int, proposedPoints: Double) -> Int {
        let currentPoints = Double(current) / 2
        let target: Double
        if currentPoints > Self.maximumPointSize {
            target = proposedPoints < currentPoints ? max(proposedPoints, Self.maximumPointSize) : currentPoints
        } else if currentPoints < Self.minimumPointSize {
            target = proposedPoints > currentPoints ? min(proposedPoints, Self.minimumPointSize) : currentPoints
        } else {
            target = min(max(proposedPoints, Self.minimumPointSize), Self.maximumPointSize)
        }
        return Int((target * 2).rounded())
    }

    private func pointRange(_ fieldID: Int) -> ClosedRange<Double> {
        let points = Double(format(for: fieldID).fontSize) / 2
        return min(Self.minimumPointSize, points)...max(Self.maximumPointSize, points)
    }

    private func pointsText(_ fieldID: Int) -> String {
        let half = format(for: fieldID).fontSize
        if half.isMultiple(of: 2) {
            return "\(half / 2) pt"
        }
        return String(format: "%.1f pt", Double(half) / 2)
    }

    private func alignmentBinding(_ fieldID: Int) -> Binding<LabelAlignment> {
        Binding(
            get: { format(for: fieldID).alignment },
            set: { newValue in
                guard isLabelSectionEnabled else { return }
                document.updateLabelFormat(phoneID: phone.id, fieldID: fieldID, undoManager: undoManager) {
                    $0.alignment = newValue
                }
            }
        )
    }

    private func colorBinding(_ fieldID: Int) -> Binding<Color> {
        Binding(
            get: { LabelStyling.color(for: format(for: fieldID).color) },
            set: { newColor in
                guard isLabelSectionEnabled else { return }
                let rgb = LabelStyling.rgbColor(from: newColor)
                guard rgb != format(for: fieldID).color else { return }
                document.updateLabelFormat(phoneID: phone.id, fieldID: fieldID, undoManager: undoManager) {
                    $0.color = rgb
                }
            }
        )
    }

    private func alignmentSymbol(_ alignment: LabelAlignment) -> String {
        switch alignment {
        case .left: "text.alignleft"
        case .center: "text.aligncenter"
        case .right: "text.alignright"
        case .justified: "text.justify"
        }
    }

    private func alignmentName(_ alignment: LabelAlignment) -> String {
        switch alignment {
        case .left: "Align Left"
        case .center: "Align Center"
        case .right: "Align Right"
        case .justified: "Justify"
        }
    }
}

/// Local ID draft. Commits through `renamePhone` on submit or when the field loses focus.
private struct PhoneIDEditor: View {
    var document: KeystripDocument
    var phoneID: String
    var undoManager: UndoManager?
    @State private var draft: String
    @State private var sourceID: String
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    init(document: KeystripDocument, phoneID: String, undoManager: UndoManager?) {
        self.document = document
        self.phoneID = phoneID
        self.undoManager = undoManager
        _draft = State(initialValue: phoneID)
        _sourceID = State(initialValue: phoneID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("ID", text: $draft)
                .focused($focused)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .onSubmit(commit)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: phoneID) { _, newID in
            guard newID != sourceID else { return }
            let pending = draft
            let previous = sourceID
            sourceID = newID
            draft = newID
            errorMessage = nil
            let trimmed = pending.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed != previous else { return }
            _ = try? document.renamePhone(id: previous, to: pending, undoManager: undoManager)
        }
    }

    private func commit() {
        do {
            let renamed = try document.renamePhone(id: sourceID, to: draft, undoManager: undoManager)
            sourceID = renamed
            draft = renamed
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            draft = sourceID
        }
    }
}
