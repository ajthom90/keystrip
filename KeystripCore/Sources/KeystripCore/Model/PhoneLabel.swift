/// One `field` row. Keeps the bytes it was read from so unedited labels are written back untouched.
public struct PhoneLabel: Equatable, Sendable {
    public var text: LabelText
    public let originalRTF: String?
    public let originalText: LabelText?
    public let isUnreadable: Bool

    /// A label created in this session.
    public init(text: LabelText) {
        self.text = text
        originalRTF = nil
        originalText = nil
        isUnreadable = false
    }

    /// A label read from a file (or copied byte for byte from another label).
    public init(rtf: String) {
        originalRTF = rtf
        if let parsed = try? RTFParser.parse(rtf) {
            text = parsed
            originalText = parsed
            isUnreadable = false
        } else {
            text = LabelText()
            originalText = LabelText()
            isUnreadable = true
        }
    }

    public var isEdited: Bool {
        originalRTF == nil || text != originalText
    }

    public var rtfForWriting: String {
        if !isEdited, let originalRTF { return originalRTF }
        return RTFWriter.write(text)
    }
}
