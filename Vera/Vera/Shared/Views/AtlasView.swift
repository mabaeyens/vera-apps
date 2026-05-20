import SwiftUI

struct AtlasView: View {
    let onTap: (AtlasItem) -> Void
    let onRemoveFormatting: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: AtlasCategory = .basics

    init(onTap: @escaping (AtlasItem) -> Void, onRemoveFormatting: (() -> Void)? = nil) {
        self.onTap = onTap
        self.onRemoveFormatting = onRemoveFormatting
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(AtlasCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 12)

                List(AtlasItem.catalog.filter { $0.category == selectedCategory }) { item in
                    Button {
                        onTap(item)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text(item.syntax.replacingOccurrences(of: "\n", with: " ↵ "))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                if let strip = onRemoveFormatting {
                    Divider()
                    Button {
                        strip()
                        dismiss()
                    } label: {
                        Label("Remove Formatting", systemImage: "eraser")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Format & Snippets")
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
