import SwiftUI

/// Headings of the current Markdown document; tap one to jump to it.
struct OutlineView: View {
    let items: [OutlineItem]
    let onSelect: (OutlineItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView("No headings", systemImage: "list.bullet.indent",
                                           description: Text("Add a line starting with # to build an outline."))
                } else {
                    List(items) { item in
                        Button { onSelect(item) } label: {
                            Text(item.title)
                                .font(item.level == 1 ? .headline : .body)
                                .foregroundStyle(item.level <= 2 ? .primary : .secondary)
                                .lineLimit(2)
                                .padding(.leading, CGFloat(item.level - 1) * 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.title), heading level \(item.level)")
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Outline")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(width: 380, height: 460)
        #else
        .presentationDetents([.medium, .large])
        #endif
    }
}
