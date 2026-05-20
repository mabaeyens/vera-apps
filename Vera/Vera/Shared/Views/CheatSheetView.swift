import SwiftUI
import MarkdownUI

struct CheatSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections, id: \.title) { section in
                    Section(isExpanded: .constant(true)) {
                        ForEach(section.entries, id: \.syntax) { entry in
                            CheatEntryRow(entry: entry)
                        }
                    } header: {
                        Text(section.title)
                    }
                }
            }
            .navigationTitle("Markdown Reference")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            #else
            .toolbar {
                ToolbarItem {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
    }
}

// MARK: - Entry row

private struct CheatEntryRow: View {
    let entry: CheatEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(entry.syntax)
                    .font(.system(.footnote, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 5))
                if !entry.shortcut.isEmpty {
                    Text(entry.shortcut)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 4))
                }
            }

            Markdown(entry.preview)
                .markdownTheme(.gitHub)
                .padding(.leading, 2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Data

private struct CheatEntry {
    let syntax: String
    let preview: String
    var shortcut: String = ""
}

private struct CheatSection {
    let title: String
    let entries: [CheatEntry]
}

private let sections: [CheatSection] = [
    CheatSection(title: "Headings", entries: [
        CheatEntry(syntax: "# Heading 1",   preview: "# Heading 1"),
        CheatEntry(syntax: "## Heading 2",  preview: "## Heading 2"),
        CheatEntry(syntax: "### Heading 3", preview: "### Heading 3"),
    ]),
    CheatSection(title: "Emphasis", entries: [
        CheatEntry(syntax: "**bold**",          preview: "**bold**",          shortcut: "⌘B"),
        CheatEntry(syntax: "*italic*",          preview: "*italic*",          shortcut: "⌘I"),
        CheatEntry(syntax: "***bold italic***", preview: "***bold italic***"),
        CheatEntry(syntax: "~~strikethrough~~", preview: "~~strikethrough~~", shortcut: "⌘⇧X"),
        CheatEntry(syntax: "`inline code`",     preview: "`inline code`",     shortcut: "⌘⇧C"),
    ]),
    CheatSection(title: "Links", entries: [
        CheatEntry(
            syntax: "[label](url)",
            preview: "[Vera](https://example.com)"
        ),
    ]),
    CheatSection(title: "Lists", entries: [
        CheatEntry(
            syntax: "- item\n- item\n  - nested",
            preview: "- item\n- item\n  - nested"
        ),
        CheatEntry(
            syntax: "1. first\n2. second\n3. third",
            preview: "1. first\n2. second\n3. third"
        ),
        CheatEntry(
            syntax: "- [ ] unchecked\n- [x] checked",
            preview: "- [ ] unchecked\n- [x] checked"
        ),
    ]),
    CheatSection(title: "Blockquote", entries: [
        CheatEntry(
            syntax: "> A blockquote\n> spanning two lines",
            preview: "> A blockquote\n> spanning two lines"
        ),
    ]),
    CheatSection(title: "Code", entries: [
        CheatEntry(
            syntax: "```swift\nlet x = 42\nprint(x)\n```",
            preview: "```swift\nlet x = 42\nprint(x)\n```"
        ),
    ]),
    CheatSection(title: "Table", entries: [
        CheatEntry(
            syntax: "| Left | Center | Right |\n|------|:------:|------:|\n| a    |   b    |     c |",
            preview: "| Left | Center | Right |\n|------|:------:|------:|\n| a    |   b    |     c |"
        ),
    ]),
    CheatSection(title: "Divider", entries: [
        CheatEntry(syntax: "---", preview: "---"),
    ]),
    CheatSection(title: "Footnote", entries: [
        CheatEntry(
            syntax: "Text with a note.[^1]\n\n[^1]: The footnote text.",
            preview: "Text with a note.[^1]\n\n[^1]: The footnote text."
        ),
    ]),
]

#Preview {
    CheatSheetView()
        .frame(width: 480, height: 640)
}
