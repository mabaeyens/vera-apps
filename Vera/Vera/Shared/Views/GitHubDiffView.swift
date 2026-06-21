import SwiftUI

/// Remembers which commit of a GitHub file the user has already seen, so Vera can
/// surface "what changed since you last looked" — the git-native wedge. (Spec C2.)
///
/// Stored in UserDefaults (not the Keychain): it's a non-secret reading bookmark,
/// keyed per owner/repo/path. Nothing leaves the device.
enum RepoSeenStore {
    private static func key(owner: String, repo: String, path: String) -> String {
        "github.seen.\(owner)/\(repo)/\(path)"
    }

    static func lastSeen(owner: String, repo: String, path: String) -> String? {
        UserDefaults.standard.string(forKey: key(owner: owner, repo: repo, path: path))
    }

    static func markSeen(owner: String, repo: String, path: String, sha: String) {
        UserDefaults.standard.set(sha, forKey: key(owner: owner, repo: repo, path: path))
    }
}

/// One line of a unified diff, classified for rendering.
struct DiffLine: Identifiable {
    enum Kind { case addition, deletion, context, hunk }
    let id = UUID()
    let kind: Kind
    let text: String
}

enum DiffParser {
    /// Parse a unified-diff `patch` (as returned by GitHub's compare API) into
    /// renderable lines. File headers (`diff --git`, `+++`, `---`, `index`) are
    /// dropped; hunk headers (`@@ … @@`) are kept as section markers.
    static func parse(_ patch: String) -> [DiffLine] {
        patch.split(separator: "\n", omittingEmptySubsequences: false).compactMap { raw in
            let line = String(raw)
            if line.hasPrefix("@@") { return DiffLine(kind: .hunk, text: line) }
            if line.hasPrefix("+++") || line.hasPrefix("---") || line.hasPrefix("diff ") || line.hasPrefix("index ") {
                return nil
            }
            if line.hasPrefix("+") { return DiffLine(kind: .addition, text: String(line.dropFirst())) }
            if line.hasPrefix("-") { return DiffLine(kind: .deletion, text: String(line.dropFirst())) }
            return DiffLine(kind: .context, text: line.hasPrefix(" ") ? String(line.dropFirst()) : line)
        }
    }
}

/// Native diff reading view: shows the unified diff for one file between the commit
/// the user last saw and the latest commit. (Spec C2.) Source-agnostic — it's given a
/// closure that returns the patch, so it doesn't depend on any particular view model.
struct GitHubDiffView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let head: GitHubCommit                       // latest commit
    let loadDiff: () async throws -> String?     // unified-diff patch for the file
    let onDone: () -> Void                        // mark the latest commit as seen

    @State private var lines: [DiffLine]?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Group {
                if let lines {
                    if lines.isEmpty {
                        ContentUnavailableView(
                            "No Textual Changes",
                            systemImage: "equal.circle",
                            description: Text("The file changed, but GitHub returned no diff to show (it may be too large or a non-text change).")
                        )
                    } else {
                        diffScroll(lines)
                    }
                } else if let errorText {
                    ContentUnavailableView {
                        Label("Couldn't Load Changes", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorText)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("What Changed")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                }
            }
        }
        .task {
            do {
                if let patch = try await loadDiff() {
                    lines = DiffParser.parse(patch)
                } else {
                    lines = []
                }
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func diffScroll(_ lines: [DiffLine]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                ForEach(lines) { line in
                    row(line)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(head.summary)
                .font(.subheadline.weight(.semibold))
            Text("\(head.authorName) · \(head.shortSHA)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.l)
        .background(.regularMaterial)
    }

    private func row(_ line: DiffLine) -> some View {
        HStack(spacing: 0) {
            Text(gutter(for: line.kind))
                .frame(width: 16, alignment: .center)
                .foregroundStyle(.secondary)
            Text(line.text.isEmpty ? " " : line.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .font(.system(.footnote, design: .monospaced))
        .padding(.vertical, 1)
        .padding(.horizontal, Theme.Space.s)
        .foregroundStyle(foreground(for: line.kind))
        .background(background(for: line.kind))
    }

    private func gutter(for kind: DiffLine.Kind) -> String {
        switch kind {
        case .addition: return "+"
        case .deletion: return "-"
        case .hunk: return "⋯"
        case .context: return ""
        }
    }

    private func foreground(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .addition: return .green
        case .deletion: return .red
        case .hunk: return .secondary
        case .context: return .primary
        }
    }

    private func background(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .addition: return .green.opacity(0.12)
        case .deletion: return .red.opacity(0.12)
        case .hunk: return .secondary.opacity(0.08)
        case .context: return .clear
        }
    }
}
