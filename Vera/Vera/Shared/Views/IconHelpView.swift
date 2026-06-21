import SwiftUI

struct IconHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Sidebar") {
                    HelpRow(symbol: "chevron.left.forwardslash.chevron.right", label: "GitHub Repository", detail: "A connected repo — expand to browse and edit its Markdown")
                    HelpRow(asset: "MarkdownMark",   label: "Markdown File", detail: "A .md file; tap to open it in a tab")
                    HelpRow(symbol: "folder.fill",   label: "Folder",        detail: "Expand to browse the files inside")
                    HelpRow(symbol: "icloud.and.arrow.down", label: "Download", detail: "File lives in iCloud — tap to download it for offline editing")
                    HelpRow(symbol: "icloud.slash",  label: "Offline",       detail: "Not downloaded and currently offline — unavailable until you reconnect")
                }
                Section("Toolbar") {
                    HelpRow(symbol: "square.and.pencil", label: "New File",  detail: "Create a new Markdown file in the current folder")
                    HelpRow(symbol: "folder",            label: "Open",      detail: "Open a folder or file to browse and edit")
                    HelpRow(symbol: "chevron.left.forwardslash.chevron.right", label: "Open from GitHub", detail: "Connect a repository to browse and edit its Markdown")
                    #if os(macOS)
                    HelpRow(symbol: "arrow.clockwise",   label: "Refresh",   detail: "Rescan the open folder for changes")
                    #endif
                    HelpRow(symbol: "questionmark.circle", label: "Icon Guide", detail: "This guide")
                    HelpRow(symbol: "info.circle",       label: "About",     detail: "App version, credits, and reset option")
                }
                Section("Editor") {
                    HelpRow(symbol: "circle.dashed",   label: "Focus Mode",   detail: "Hide the surrounding panels for distraction-free writing")
                    HelpRow(symbol: "wand.and.sparkles", label: "Auto-fix",   detail: "Repair heading spacing, blank lines, trailing whitespace and smart quotes")
                    HelpRow(symbol: "paintbrush",      label: "Format & Snippets", detail: "Apply bold, italic, code, links and structural snippets; or remove all formatting")
                    HelpRow(symbol: "book.closed",     label: "Markdown Reference", detail: "Open the Markdown syntax cheat sheet")
                    HelpRow(symbol: "textformat.size", label: "Text Size",    detail: "Increase or decrease the editor font size")
                    #if os(macOS)
                    HelpRow(symbol: "doc.on.doc",      label: "Copy All Text", detail: "Copy the whole document to the clipboard")
                    #endif
                }
                Section("GitHub editing") {
                    HelpRow(symbol: "arrow.up.circle",          label: "Commit",       detail: "Commit your changes to the branch or open a pull request")
                    HelpRow(symbol: "plus.forwardslash.minus",  label: "What Changed", detail: "Show a diff when the file moved on since you opened it")
                }
                Section("Keyboard shortcuts") {
                    HelpRow(symbol: "bold",          label: "⌘B",  detail: "Bold")
                    HelpRow(symbol: "italic",        label: "⌘I",  detail: "Italic")
                    HelpRow(symbol: "strikethrough", label: "⌘⇧X", detail: "Strikethrough")
                    HelpRow(symbol: "chevron.left.forwardslash.chevron.right", label: "⌘⇧C", detail: "Inline code")
                }
            }
            .navigationTitle("Icon Guide")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }
}

private struct HelpRow: View {
    let symbol: String?
    let asset: String?
    let label: String
    let detail: String

    init(symbol: String, label: String, detail: String) {
        self.symbol = symbol; self.asset = nil; self.label = label; self.detail = detail
    }

    init(asset: String, label: String, detail: String) {
        self.symbol = nil; self.asset = asset; self.label = label; self.detail = detail
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            icon
                .frame(width: 28, alignment: .center)
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var icon: some View {
        if let symbol {
            Image(systemName: symbol).font(.title3)
        } else if let asset {
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
    }
}
