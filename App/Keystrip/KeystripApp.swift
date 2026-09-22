import SwiftUI

@main
struct KeystripApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { KeystripDocument() }) { file in
            ContentView(document: file.document)
        }
    }
}
