public enum RTFWriter {
    public static func write(_ text: LabelText) -> String {
        var out = #"{\rtf1\ansi{\fonttbl{\f0\ftnil "#
        out += escape(text.fontFace)
        out += #";}}{\colortbl\red\#(text.color.red)\green\#(text.color.green)\blue\#(text.color.blue);}"#
        out += #"\f0\cf0\fs\#(text.fontSize)\q"# + text.alignment.rawValue
        if text.baseStyle.bold { out += #"\b"# }
        if text.baseStyle.italic { out += #"\i"# }
        if text.baseStyle.underline { out += #"\ul"# }
        out += " "

        var current = text.baseStyle
        for (index, paragraph) in text.paragraphs.enumerated() {
            if index > 0 { out += #"\par "# }
            for run in paragraph where !run.text.isEmpty {
                if run.style != current {
                    out += changes(from: current, to: run.style) + " "
                    current = run.style
                }
                out += escape(run.text)
            }
        }
        out += "}"
        return out
    }

    private static func changes(from old: TextStyle, to new: TextStyle) -> String {
        var words = ""
        if old.bold != new.bold { words += new.bold ? #"\b"# : #"\b0"# }
        if old.italic != new.italic { words += new.italic ? #"\i"# : #"\i0"# }
        if old.underline != new.underline { words += new.underline ? #"\ul"# : #"\ulnone"# }
        return words
    }

    static func escape(_ string: String) -> String {
        var out = ""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\\": out += #"\\"#
            case "{": out += #"\{"#
            case "}": out += #"\}"#
            case "\t": out += #"\tab "#
            case "\n", "\r": out += #"\par "#
            default:
                let value = scalar.value
                if value < 0x20 || value == 0x7F {
                    continue
                } else if value < 0x7F {
                    out.unicodeScalars.append(scalar)
                } else if let byte = Windows1252.encode(scalar) {
                    out += #"\'"# + String(byte, radix: 16).leftPadded(to: 2)
                } else {
                    for unit in String(scalar).utf16 {
                        out += #"\u"# + String(Int16(bitPattern: unit)) + "?"
                    }
                }
            }
        }
        return out
    }
}

private extension String {
    func leftPadded(to width: Int) -> String {
        count >= width ? self : String(repeating: "0", count: width - count) + self
    }
}
