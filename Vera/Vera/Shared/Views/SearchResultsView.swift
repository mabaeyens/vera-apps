import SwiftUI

/// Folder-search results, shown in place of the file tree while a query is active.
///
/// Filename matches come first — when you're looking for a file, that's the answer — then
/// content matches grouped by file.
struct SearchResultsView: View {
    let hits: [SearchHit]
    let isSearching: Bool
    let truncated: Bool
    let skips: [SearchSkip]
    let query: String
    let onOpen: (SearchHit) -> Void

    private var filenameHits: [SearchHit] { hits.filter(\.isFilenameMatch) }
    private var contentHits: [SearchHit] { hits.filter { !$0.isFilenameMatch } }

    /// Grouped by file, preserving discovery order so results don't reshuffle as they stream in.
    private var groupedContent: [(url: URL, hits: [SearchHit])] {
        var order: [URL] = []
        var byURL: [URL: [SearchHit]] = [:]
        for hit in contentHits {
            if byURL[hit.url] == nil { order.append(hit.url) }
            byURL[hit.url, default: []].append(hit)
        }
        return order.map { ($0, byURL[$0] ?? []) }
    }

    var body: some View {
        List {
            if hits.isEmpty && !isSearching {
                ContentUnavailableView.search(text: query)
                    .listRowSeparator(.hidden)
            }

            if !filenameHits.isEmpty {
                Section("Files") {
                    ForEach(filenameHits) { hit in
                        Button { onOpen(hit) } label: {
                            Label {
                                Text(hit.name).lineLimit(1).truncationMode(.middle)
                            } icon: {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ForEach(groupedContent, id: \.url) { group in
                Section {
                    ForEach(group.hits) { hit in
                        Button { onOpen(hit) } label: {
                            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
                                Text("\(hit.lineNumber)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                                    .frame(minWidth: 28, alignment: .trailing)
                                Text(hit.line)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(group.url.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if isSearching {
                HStack(spacing: Theme.Space.s) {
                    ProgressView().controlSize(.small)
                    Text("Searching…").foregroundStyle(.secondary)
                }
                .font(.footnote)
            }

            // Never let the result set imply coverage it doesn't have.
            if truncated {
                Label(
                    "Showing the first \(FolderSearch.maxResults) matches. Narrow the search to see more.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            if !skips.isEmpty {
                Label(skipSummary, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
    }

    private var skipSummary: String {
        let notDownloaded = skips.compactMap { if case .notDownloaded(let n) = $0 { return n } else { return nil } }
        let tooLarge = skips.compactMap { if case .tooLarge(let n) = $0 { return n } else { return nil } }
        var parts: [String] = []
        if !notDownloaded.isEmpty {
            parts.append("\(notDownloaded.count) file\(notDownloaded.count == 1 ? "" : "s") not downloaded from iCloud")
        }
        if !tooLarge.isEmpty {
            parts.append("\(tooLarge.count) file\(tooLarge.count == 1 ? "" : "s") over \(FolderSearch.maxFileBytes / 1_000_000) MB")
        }
        return "Not searched: " + parts.joined(separator: ", ") + "."
    }
}
