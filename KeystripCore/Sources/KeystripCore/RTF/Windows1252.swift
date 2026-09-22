/// Windows code page 1252, which DESI's `\ansi` RTF uses for `\'hh` escapes.
enum Windows1252 {
    /// Unicode scalar values for bytes 0x80...0x9F. Zero marks bytes 1252 leaves undefined.
    private static let high: [UInt32] = [
        0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
        0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0, 0x017D, 0,
        0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
        0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178,
    ]

    static func decode(_ byte: UInt8) -> Unicode.Scalar {
        guard (0x80...0x9F).contains(byte) else { return Unicode.Scalar(byte) }
        let value = high[Int(byte - 0x80)]
        return value == 0 ? "\u{FFFD}" : Unicode.Scalar(value)!
    }

    static func encode(_ scalar: Unicode.Scalar) -> UInt8? {
        let value = scalar.value
        if value < 0x80 || (0xA0...0xFF).contains(value) { return UInt8(value) }
        if let offset = high.firstIndex(of: value) { return UInt8(0x80 + offset) }
        return nil
    }
}
