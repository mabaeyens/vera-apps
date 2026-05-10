import Foundation

enum AtlasCategory: String, CaseIterable, Identifiable {
    case basics = "Basics"
    case structure = "Structure"
    case media = "Media"
    case advanced = "Advanced"
    var id: String { rawValue }
}

struct AtlasItem: Identifiable {
    let id = UUID()
    let label: String
    let syntax: String
    let category: AtlasCategory
}

extension AtlasItem {
    static let catalog: [AtlasItem] = [
        .init(label: "Bold",        syntax: "**bold**",                         category: .basics),
        .init(label: "Italic",      syntax: "*italic*",                         category: .basics),
        .init(label: "Bold italic", syntax: "***bold italic***",                category: .basics),
        .init(label: "Strike",      syntax: "~~text~~",                         category: .basics),
        .init(label: "Code",        syntax: "`code`",                           category: .basics),
        .init(label: "Link",        syntax: "[label](url)",                     category: .basics),

        .init(label: "H1",          syntax: "# Heading",                        category: .structure),
        .init(label: "H2",          syntax: "## Heading",                       category: .structure),
        .init(label: "H3",          syntax: "### Heading",                      category: .structure),
        .init(label: "Bullet",      syntax: "- item",                           category: .structure),
        .init(label: "Numbered",    syntax: "1. item",                          category: .structure),
        .init(label: "Quote",       syntax: "> quote",                          category: .structure),
        .init(label: "Divider",     syntax: "---",                              category: .structure),
        .init(label: "Code block",  syntax: "```\ncode\n```",                   category: .structure),
        .init(label: "Table",       syntax: "| A | B |\n|---|---|\n| 1 | 2 |", category: .structure),

        .init(label: "Image",       syntax: "![alt](url)",                      category: .media),
        .init(label: "Image link",  syntax: "[![alt](img)](url)",               category: .media),

        .init(label: "Task",        syntax: "- [ ] task",                       category: .advanced),
        .init(label: "Done task",   syntax: "- [x] done",                       category: .advanced),
        .init(label: "Footnote",    syntax: "text[^1]\n\n[^1]: note",           category: .advanced),
    ]
}
