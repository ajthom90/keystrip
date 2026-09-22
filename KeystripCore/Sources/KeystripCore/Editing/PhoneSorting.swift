import Foundation

public enum PhoneSortOrder: String, CaseIterable, Sendable {
    case id
    case name
}

public enum PhoneSorting {
    public static func sorted(_ phones: [Phone], by order: PhoneSortOrder) -> [Phone] {
        switch order {
        case .id:
            phones.sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
        case .name:
            phones.sorted { a, b in
                let aNamed = !a.name.isEmpty
                let bNamed = !b.name.isEmpty
                if aNamed != bNamed { return aNamed }
                if aNamed {
                    let names = a.name.localizedStandardCompare(b.name)
                    if names != .orderedSame { return names == .orderedAscending }
                }
                return a.id.localizedStandardCompare(b.id) == .orderedAscending
            }
        }
    }

    public static func filter(_ phones: [Phone], matching query: String) -> [Phone] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return phones }
        return phones.filter {
            $0.id.localizedCaseInsensitiveContains(query) || $0.name.localizedCaseInsensitiveContains(query)
        }
    }
}
