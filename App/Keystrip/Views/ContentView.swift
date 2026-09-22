import KeystripCore
import SwiftUI

struct ContentView: View {
    var document: KeystripDocument
    @State private var activeFieldID: Int?

    var body: some View {
        NavigationSplitView {
            PhoneListView(document: document)
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
        } detail: {
            if let phone = selectedPhone {
                PhoneEditorView(document: document, phone: phone, activeFieldID: $activeFieldID)
            } else {
                ContentUnavailableView(
                    "No Phone Selected",
                    systemImage: "phone",
                    description: Text("Pick a phone from the list or add one.")
                )
            }
        }
        .onChange(of: document.data.selectedPhoneID) { _, _ in
            activeFieldID = nil
        }
    }

    private var selectedPhone: Phone? {
        guard let id = document.data.selectedPhoneID else { return nil }
        return document.data.phone(withID: id)
    }
}
