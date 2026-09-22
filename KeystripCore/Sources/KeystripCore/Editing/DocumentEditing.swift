import Foundation

public enum EditError: Error, LocalizedError, Equatable, Sendable {
    case emptyPhoneID
    case duplicatePhoneID(String)
    case noSuchPhone(String)

    public var errorDescription: String? {
        switch self {
        case .emptyPhoneID:
            "A phone needs an ID."
        case .duplicatePhoneID(let id):
            "A phone with the ID \"\(id)\" already exists."
        case .noSuchPhone(let id):
            "There is no phone with the ID \"\(id)\"."
        }
    }
}

extension DSIDocumentData {
    public func validatedPhoneID(_ raw: String, excluding current: String? = nil) throws -> String {
        let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { throw EditError.emptyPhoneID }
        if phones.contains(where: { $0.id == id && $0.id != current }) {
            throw EditError.duplicatePhoneID(id)
        }
        return id
    }

    @discardableResult
    public mutating func addPhone(
        id: String,
        name: String,
        typecode: String,
        copyingFrom sourceID: String? = nil,
        includeNameStrip: Bool = false,
        now: String = DESITimestamp.now()
    ) throws -> String {
        let id = try validatedPhoneID(id)
        var fields: [Int: PhoneLabel] = [:]
        if let sourceID {
            guard let source = phone(withID: sourceID) else { throw EditError.noSuchPhone(sourceID) }
            for (fieldID, label) in source.fields {
                if fieldID == PhoneModel.nameStripFieldID && !includeNameStrip { continue }
                fields[fieldID] = PhoneLabel(rtf: label.rtfForWriting)
            }
        }
        phones.append(Phone(id: id, typecode: typecode, name: name, modified: now, fields: fields))
        return id
    }

    public mutating func deletePhone(id: String) throws {
        let index = try phoneIndex(id)
        phones.remove(at: index)
        if selectedPhoneID == id { selectedPhoneID = nil }
    }

    @discardableResult
    public mutating func renamePhone(id: String, to newID: String, now: String = DESITimestamp.now()) throws -> String {
        let index = try phoneIndex(id)
        let newID = try validatedPhoneID(newID, excluding: id)
        guard newID != id else { return id }
        phones[index].id = newID
        phones[index].modified = now
        if selectedPhoneID == id { selectedPhoneID = newID }
        return newID
    }

    public mutating func setName(_ name: String, phoneID: String, now: String = DESITimestamp.now()) throws {
        let index = try phoneIndex(phoneID)
        guard phones[index].name != name else { return }
        phones[index].name = name
        phones[index].modified = now
    }

    public mutating func setTypecode(_ typecode: String, phoneID: String, now: String = DESITimestamp.now()) throws {
        let index = try phoneIndex(phoneID)
        guard phones[index].typecode != typecode else { return }
        phones[index].typecode = typecode
        phones[index].modified = now
    }

    public mutating func setLabelText(_ text: String, phoneID: String, fieldID: Int, now: String = DESITimestamp.now()) throws {
        let index = try phoneIndex(phoneID)
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        if var label = phones[index].fields[fieldID] {
            guard !label.isUnreadable else { return }
            guard label.text.plainText != normalized else { return }
            if normalized.isEmpty && label.originalRTF == nil {
                phones[index].fields[fieldID] = nil
            } else {
                label.text = label.text.replacingText(normalized)
                phones[index].fields[fieldID] = label
            }
            phones[index].modified = now
            return
        }

        guard !normalized.isEmpty else { return }
        phones[index].fields[fieldID] = PhoneLabel(text: LabelText.template(forFieldID: fieldID).replacingText(normalized))
        phones[index].modified = now
    }

    public mutating func updateLabelFormat(
        phoneID: String,
        fieldID: Int,
        now: String = DESITimestamp.now(),
        _ change: (inout LabelFormat) -> Void
    ) throws {
        let index = try phoneIndex(phoneID)
        if phones[index].fields[fieldID]?.isUnreadable == true { return }

        var text = phones[index].fields[fieldID]?.text ?? LabelText.template(forFieldID: fieldID)
        var format = text.format
        change(&format)
        guard format != text.format else { return }
        text.format = format

        if var label = phones[index].fields[fieldID] {
            label.text = text
            phones[index].fields[fieldID] = label
        } else {
            phones[index].fields[fieldID] = PhoneLabel(text: text)
        }
        phones[index].modified = now
    }

    private func phoneIndex(_ id: String) throws -> Int {
        guard let index = index(ofPhone: id) else { throw EditError.noSuchPhone(id) }
        return index
    }
}
