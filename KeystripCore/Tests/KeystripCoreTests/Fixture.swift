import Foundation
import Testing
@testable import KeystripCore

enum Fixture {
    static func data() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "sample", withExtension: "dsi", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    static func document() throws -> DSIDocumentData {
        try DSIReader.read(data())
    }

    /// A header prefix shared by most fixture labels.
    static let header = #"{\rtf1\ansi{\fonttbl{\f0\ftnil Arial;}}{\colortbl\red0\green0\blue0;}\f0\cf0\fs18\qc"#
}
