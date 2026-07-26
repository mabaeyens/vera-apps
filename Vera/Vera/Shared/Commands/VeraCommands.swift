import SwiftUI

/// Vera's menu bar and keyboard shortcuts.
///
/// Before this, the app declared no `.commands` at all, so macOS showed SwiftUI's bare
/// default menus, and the whole app had three `.keyboardShortcut` calls — one of which
/// (⌘O) hung off a toolbar button and so only worked while that toolbar existed.
///
/// Nothing here reimplements an action. Text edits go through the same
/// `wrapSelection` / `insertAtCursor` closures the formatting bar uses, which
/// `HighlightingTextView` registers on the active `EditorViewModel`; sheet-driven items
/// post the same notifications the toolbar posts. That also gives correct enablement for
/// free: those closures are only non-nil while an editor is actually mounted.
@MainActor
struct VeraCommands: Commands {
    let vm: FileTreeViewModel

    @AppStorage(Defaults.Key.editorFontSize) private var fontSize = Defaults.FontSize.default
    @AppStorage(Defaults.Key.focusMode) private var focusMode = false
    @AppStorage(Defaults.Key.lineNumbersEnabled) private var lineNumbers = true
    @AppStorage(Defaults.Key.codeWrapEnabled) private var wrapCode = false

    /// The document the user is actually looking at. Reachable at all now that editors
    /// live on the tab rather than inside the view that displays them.
    private var activeEditor: EditorViewModel? {
        vm.tabs.first { $0.id == vm.activeTabID }?.editor
    }

    /// Markdown-only formatting, and only while the editor is up.
    private var canFormat: Bool {
        guard let editor = activeEditor else { return false }
        return editor.format == .markdown && editor.wrapSelection != nil
    }

    private static func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }

    var body: some Commands {
        // MARK: File

        CommandGroup(replacing: .newItem) {
            Button("New File…") { Self.post(.veraNewFile) }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(vm.rootURL == nil)

            Button("Open File…") { Self.post(.veraOpenPicker) }
                .keyboardShortcut("o", modifiers: .command)

            Button("Open Folder…") { Self.post(.veraOpenPicker) }
                .keyboardShortcut("o", modifiers: [.command, .shift])

            Button("Open from GitHub…") { Self.post(.veraOpenGitHub) }
        }

        CommandGroup(replacing: .saveItem) {
            // Vera autosaves on a 500ms debounce, but people press ⌘S regardless and it
            // must never be a no-op — this flushes the pending write immediately.
            Button("Save") {
                guard let editor = activeEditor else { return }
                Task { await editor.flushPendingSave() }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(activeEditor == nil)

            Divider()

            Button("Close") {
                if let id = vm.activeTabID { vm.closeTab(id) }
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(vm.activeTabID == nil)
        }

        // MARK: Format

        CommandMenu("Format") {
            // `CommandMenu` itself takes no `.disabled`, so the gate goes on grouped
            // content. Groups also keep each block within the ViewBuilder's 10-item limit.
            Group {
                Button("Bold") { activeEditor?.wrapSelection?("**", "**") }
                    .keyboardShortcut("b", modifiers: .command)
                Button("Italic") { activeEditor?.wrapSelection?("_", "_") }
                    .keyboardShortcut("i", modifiers: .command)
                Button("Strikethrough") { activeEditor?.wrapSelection?("~~", "~~") }
                    .keyboardShortcut("x", modifiers: [.command, .shift])
                Button("Inline Code") { activeEditor?.wrapSelection?("`", "`") }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Link") { activeEditor?.wrapSelection?("[", "](https://)") }
                    .keyboardShortcut("k", modifiers: .command)
            }
            .disabled(!canFormat)

            Divider()

            Group {
                // Control-Command, not plain Command: ⌘1…9 switch documents (Navigate
                // menu below), the more frequent action and the more common convention.
                Button("Heading 1") { activeEditor?.insertAtCursor?("# ") }
                    .keyboardShortcut("1", modifiers: [.command, .control])
                Button("Heading 2") { activeEditor?.insertAtCursor?("## ") }
                    .keyboardShortcut("2", modifiers: [.command, .control])
                Button("Heading 3") { activeEditor?.insertAtCursor?("### ") }
                    .keyboardShortcut("3", modifiers: [.command, .control])
            }
            .disabled(!canFormat)

            Divider()

            Group {
                Button("Bullet List") { activeEditor?.insertAtCursor?("- ") }
                Button("Numbered List") { activeEditor?.insertAtCursor?("1. ") }
                Button("Blockquote") { activeEditor?.insertAtCursor?("> ") }
                Button("Code Block") { activeEditor?.insertAtCursor?("```\n\n```") }
            }
            .disabled(!canFormat)
        }

        // MARK: View

        CommandGroup(after: .toolbar) {
            Button(activeEditor?.mode == .editing ? "Preview" : "Edit") {
                guard let editor = activeEditor, editor.canEdit else { return }
                editor.mode = editor.mode == .editing ? .viewing : .editing
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(activeEditor?.canEdit != true)

            Toggle("Focus Mode", isOn: Binding(get: { focusMode }, set: { focusMode = $0 }))
                .keyboardShortcut("f", modifiers: [.command, .shift])

            Divider()

            Button("Larger Text") { fontSize = Defaults.FontSize.increased(from: fontSize) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Smaller Text") { fontSize = Defaults.FontSize.decreased(from: fontSize) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Actual Size") { fontSize = Double(Theme.Typography.codeSize) }
                .keyboardShortcut("0", modifiers: .command)

            Divider()

            Toggle("Line Numbers", isOn: Binding(get: { lineNumbers }, set: { lineNumbers = $0 }))
            Toggle("Wrap Lines", isOn: Binding(get: { wrapCode }, set: { wrapCode = $0 }))
        }

        // MARK: Navigate

        CommandMenu("Navigate") {
            Button("Next Document") { cycleDocument(by: 1) }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(vm.tabs.count < 2)
            Button("Previous Document") { cycleDocument(by: -1) }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(vm.tabs.count < 2)

            Divider()

            // ⌘1…9 select the Nth open document, the convention in browsers and editors.
            ForEach(Array(vm.tabs.prefix(9).enumerated()), id: \.element.id) { index, tab in
                Button(tab.name) { vm.activateTab(tab.id) }
                    .keyboardShortcut(
                        KeyEquivalent(Character("\(index + 1)")),
                        modifiers: .command
                    )
            }
        }

        // MARK: Help

        CommandGroup(replacing: .help) {
            Button("Markdown Reference") { Self.post(.veraCheatSheet) }
            Button("Icon Guide") { Self.post(.veraIconGuide) }
        }

        #if os(macOS)
        CommandGroup(replacing: .appInfo) {
            Button("About Vera") { Self.post(.veraAbout) }
        }
        #endif
    }

    private func cycleDocument(by offset: Int) {
        guard !vm.tabs.isEmpty,
              let current = vm.tabs.firstIndex(where: { $0.id == vm.activeTabID })
        else { return }
        let next = (current + offset + vm.tabs.count) % vm.tabs.count
        vm.activateTab(vm.tabs[next].id)
    }
}
