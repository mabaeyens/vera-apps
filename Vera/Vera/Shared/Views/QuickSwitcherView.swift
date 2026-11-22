import SwiftUI

/// Jump to a file by name. Empty query shows recent files; typing fuzzy-matches the file
/// name first and its folder path second.
struct QuickSwitcherView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var files: [URL] = []
    @State private var isIndexing = false
    @FocusState private var fieldFocused: Bool

    private struct Entry: Identifiable {
        let url: URL
        let relativePath: String
        var id: URL { url }
        var name: String { url.deletingPathExtension().lastPathComponent }
        var folder: String {
            let dir = (relativePath as NSString).deletingLastPathComponent
            return dir.isEmpty ? "" : dir
        }
    }

    private var root: URL? { vm.rootURL }

    private func entry(for url: URL) -> Entry {
        Entry(url: url, relativePath: root.map { FileIndex.relativePath(of: url, to: $0) } ?? url.lastPathComponent)
    }

    private var results: [Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.isEmpty { return vm.recentFiles().map(entry(for:)) }

        return files
            .compactMap { url -> (Entry, Int)? in
                let e = entry(for: url)
                guard let score = Self.score(trimmed, name: e.name.lowercased(), path: e.relativePath.lowercased())
                else { return nil }
                return (e, score)
            }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.name.localizedCaseInsensitiveCompare($1.0.name) == .orderedAscending }
            .prefix(60)
            .map(\.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Go to file…", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(14)
                .focused($fieldFocused)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .onSubmit { if let first = results.first { open(first) } }
                .accessibilityLabel("Go to file")

            Divider()

            let shown = results
            if shown.isEmpty {
                ContentUnavailableView(
                    isIndexing ? "Indexing…" : (query.isEmpty ? "No recent files" : "No matching files"),
                    systemImage: isIndexing ? "hourglass" : "doc.text.magnifyingglass"
                )
            } else {
                List(shown) { item in
                    Button { open(item) } label: {
                        HStack(spacing: 8) {
                            Text(item.name).lineLimit(1)
                            if !item.folder.isEmpty {
                                Text(item.folder)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        #if os(macOS)
        .frame(width: 520, height: 420)
        #endif
        .task {
            fieldFocused = true
            guard let root else { return }
            isIndexing = true
            files = await FileIndex.build(root: root)
            isIndexing = false
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    private func open(_ entry: Entry) {
        dismiss()
        vm.openFileInNewTab(entry.url)
    }

    /// Higher is better; nil means no match. A name match always beats a path-only match.
    static func score(_ query: String, name: String, path: String) -> Int? {
        if name == query { return 1000 }
        if name.hasPrefix(query) { return 900 - min(name.count, 100) }
        if let range = name.range(of: query) {
            return 800 - name.distance(from: name.startIndex, to: range.lowerBound)
        }
        if isSubsequence(query, of: name) { return 500 - min(name.count, 100) }
        if path.contains(query) { return 300 }
        if isSubsequence(query, of: path) { return 100 }
        return nil
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var remaining = needle[...]
        for char in haystack {
            guard let next = remaining.first else { return true }
            if char == next { remaining = remaining.dropFirst() }
        }
        return remaining.isEmpty
    }
}
