import SwiftUI

struct IconHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Sidebar") {
                    HelpRow(symbol: "folder",            label: "Choose Folder", detail: "Pick a folder to browse its Markdown files")
                    HelpRow(symbol: "square.and.pencil", label: "New File",      detail: "Create a new Markdown file in the current folder")
                    HelpRow(symbol: "info.circle",       label: "About",         detail: "App version, credits, and reset option")
                }
                Section("Document toolbar") {
                    HelpRow(symbol: "wand.and.stars",  label: "Atlas",       detail: "AI writing assistant — summarise, rewrite, expand, insert snippets, or strip formatting")
                    HelpRow(symbol: "textformat.size", label: "Text Size",   detail: "Increase or decrease the editor font size; also opens the Markdown Reference cheat sheet")
                    HelpRow(symbol: "pencil",          label: "Edit / Done", detail: "Switch between reading and editing mode")
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
    let symbol: String
    let label: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
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
}
