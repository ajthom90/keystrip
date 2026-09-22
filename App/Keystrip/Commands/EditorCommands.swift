import SwiftUI

/// Menu actions for the focused document window.
struct EditorActions {
    var canModifyPhone: Bool
    var canEditLabel: Bool
    var newPhone: @MainActor () -> Void
    var duplicatePhone: @MainActor () -> Void
    var deletePhone: @MainActor () -> Void
    var toggleBold: @MainActor () -> Void
    var toggleItalic: @MainActor () -> Void
    var toggleUnderline: @MainActor () -> Void
    var increaseFontSize: @MainActor () -> Void
    var decreaseFontSize: @MainActor () -> Void
    var alignLeft: @MainActor () -> Void
    var alignCenter: @MainActor () -> Void
    var alignRight: @MainActor () -> Void
    var toggleInspector: @MainActor () -> Void
}

extension FocusedValues {
    @Entry var editorActions: EditorActions?
}

/// Phone and Format menus. Items stay disabled until a document publishes `editorActions`.
struct EditorCommands: Commands {
    @FocusedValue(\.editorActions) private var actions

    var body: some Commands {
        CommandMenu("Phone") {
            Button("New Phone", action: { actions?.newPhone() })
                .keyboardShortcut("n", modifiers: [.shift, .command])
                .disabled(actions == nil)
            Button("Duplicate Phone", action: { actions?.duplicatePhone() })
                .keyboardShortcut("d", modifiers: .command)
                .disabled(actions?.canModifyPhone != true)
            Button("Delete Phone", action: { actions?.deletePhone() })
                .disabled(actions?.canModifyPhone != true)
        }
        CommandMenu("Format") {
            Button("Bold", action: { actions?.toggleBold() })
                .keyboardShortcut("b", modifiers: .command)
                .disabled(actions?.canEditLabel != true)
            Button("Italic", action: { actions?.toggleItalic() })
                .keyboardShortcut("i", modifiers: .command)
                .disabled(actions?.canEditLabel != true)
            Button("Underline", action: { actions?.toggleUnderline() })
                .keyboardShortcut("u", modifiers: .command)
                .disabled(actions?.canEditLabel != true)
            Divider()
            Button("Bigger", action: { actions?.increaseFontSize() })
                .keyboardShortcut("+", modifiers: .command)
                .disabled(actions?.canEditLabel != true)
            Button("Smaller", action: { actions?.decreaseFontSize() })
                .keyboardShortcut("-", modifiers: .command)
                .disabled(actions?.canEditLabel != true)
            Divider()
            Button("Align Left", action: { actions?.alignLeft() })
                .keyboardShortcut("{", modifiers: .command)
                .disabled(actions?.canEditLabel != true)
            Button("Align Center", action: { actions?.alignCenter() })
                .keyboardShortcut("|", modifiers: .command)
                .disabled(actions?.canEditLabel != true)
            Button("Align Right", action: { actions?.alignRight() })
                .keyboardShortcut("}", modifiers: .command)
                .disabled(actions?.canEditLabel != true)
        }
        CommandGroup(after: .sidebar) {
            Button("Toggle Inspector", action: { actions?.toggleInspector() })
                .keyboardShortcut("i", modifiers: [.option, .command])
                .disabled(actions == nil)
        }
    }
}
