import Foundation

/// DESI's `extension.modified` format: local time as `yyyyMMdd'T'HHmmss`.
public enum DESITimestamp {
    public static func string(from date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "%04d%02d%02dT%02d%02d%02d",
            c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0, c.second ?? 0
        )
    }

    public static func now() -> String {
        string(from: Date())
    }
}
