public enum RTFError: Error, Equatable, Sendable {
    /// The input does not start with `{\rtf`.
    case notRTF
    case malformed(String)
}

enum RTFToken: Equatable {
    case groupStart
    case groupEnd
    case controlWord(String, Int?)
    case controlSymbol(Character)
    case hexByte(UInt8)
    case text(String)
}

enum RTFTokenizer {
    static func tokenize(_ input: String) throws -> [RTFToken] {
        let scalars = Array(input.unicodeScalars)
        var tokens: [RTFToken] = []
        var text = String.UnicodeScalarView()
        var index = 0

        func flushText() {
            guard !text.isEmpty else { return }
            tokens.append(.text(String(text)))
            text = String.UnicodeScalarView()
        }

        while index < scalars.count {
            let scalar = scalars[index]
            switch scalar {
            case "{":
                flushText()
                tokens.append(.groupStart)
                index += 1
            case "}":
                flushText()
                tokens.append(.groupEnd)
                index += 1
            case "\r", "\n":
                index += 1
            case "\\":
                flushText()
                index += 1
                guard index < scalars.count else { throw RTFError.malformed("backslash at end of input") }
                let next = scalars[index]
                if isASCIILetter(next) {
                    var name = String.UnicodeScalarView()
                    while index < scalars.count, isASCIILetter(scalars[index]), name.count < 32 {
                        name.append(scalars[index])
                        index += 1
                    }
                    var digits = String.UnicodeScalarView()
                    if index + 1 < scalars.count, scalars[index] == "-", isASCIIDigit(scalars[index + 1]) {
                        digits.append("-")
                        index += 1
                    }
                    while index < scalars.count, isASCIIDigit(scalars[index]), digits.count < 11 {
                        digits.append(scalars[index])
                        index += 1
                    }
                    if index < scalars.count, scalars[index] == " " {
                        index += 1
                    }
                    tokens.append(.controlWord(String(name), digits.isEmpty ? nil : Int(String(digits))))
                } else if next == "'" {
                    guard index + 2 < scalars.count,
                          scalars[index + 1].properties.isASCIIHexDigit,
                          scalars[index + 2].properties.isASCIIHexDigit
                    else { throw RTFError.malformed("bad \\' escape") }
                    var hex = String.UnicodeScalarView()
                    hex.append(scalars[index + 1])
                    hex.append(scalars[index + 2])
                    tokens.append(.hexByte(UInt8(String(hex), radix: 16)!))
                    index += 3
                } else if next == "\r" || next == "\n" {
                    tokens.append(.controlWord("par", nil))
                    index += 1
                } else {
                    tokens.append(.controlSymbol(Character(next)))
                    index += 1
                }
            default:
                text.append(scalar)
                index += 1
            }
        }
        flushText()
        return tokens
    }

    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
    }

    private static func isASCIIDigit(_ scalar: Unicode.Scalar) -> Bool {
        ("0"..."9").contains(scalar)
    }
}
