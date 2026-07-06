import SwiftUI

/// Commit multiple dirty GitHub files in a single atomic commit (Git Data API).
/// Presented from `GitHubBrowserView` when ≥2 files have unsaved edits.
struct MultiFileCommitSheet: View {
    @Environment(\.dismiss) private var dismiss

    let owner: String
    let repo: String
    let branch: String
    let drafts: [GitHubDraftStore.Draft]
    let fetchBranches: () async -> [String]
    /// Perform the commit; `files` contains only the checked items.
    /// Returns the URL to display (commit or PR), if any.
    let commit: (_ files: [(path: String, text: String, blobSHA: String)],
                 _ message: String,
                 _ openPR: Bool,
                 _ targetBranch: String) async throws -> URL?

    enum Mode: String, CaseIterable, Identifiable {
        case commit = "Commit"
        case pullRequest = "Pull Request"
        var id: String { rawValue }
    }

    @State private var selected: Set<GitHubFileRef> = []  // refs of checked files (unique per branch)
    @State private var message: String = ""
    @State private var mode: Mode = .commit
    @State private var selectedBranch: String = ""
    @State private var availableBranches: [String] = []
    @State private var loadingBranches = false
    @State private var isCommitting = false
    @State private var errorText: String?
    @State private var resultURL: URL?

    private var targetBranch: String {
        selectedBranch.isEmpty ? branch : selectedBranch
    }

    private var checkedDrafts: [GitHubDraftStore.Draft] {
        drafts.filter { selected.contains($0.ref) }
    }

    private var canCommit: Bool {
        !isCommitting && !selected.isEmpty && !message.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if let resultURL {
                    successView(resultURL)
                } else {
                    form
                }
            }
            .navigationTitle("Commit Files")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(resultURL == nil ? "Cancel" : "Done") { dismiss() }
                }
                if resultURL == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        if isCommitting {
                            ProgressView()
                        } else {
                            Button(mode == .commit ? "Commit" : "Open PR") {
                                Task { await performCommit() }
                            }
                            .disabled(!canCommit)
                        }
                    }
                }
            }
        }
        .onAppear {
            selected = Set(drafts.map(\.ref))
            if message.isEmpty { message = "Update \(owner)/\(repo)" }
            if selectedBranch.isEmpty { selectedBranch = branch }
        }
    }

    private var form: some View {
        Form {
            Section("Changed Files") {
                ForEach(drafts) { draft in
                    Toggle(isOn: Binding(
                        get: { selected.contains(draft.ref) },
                        set: { on in
                            if on { selected.insert(draft.ref) }
                            else  { selected.remove(draft.ref)  }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(draft.fileName).font(.body)
                            Text(draft.ref.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }

            Section {
                TextField("Commit message", text: $message, axis: .vertical)
                    .lineLimit(1...4)
            }

            Section {
                Picker("Destination", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if loadingBranches {
                    HStack {
                        Text("Branch").foregroundStyle(.secondary)
                        Spacer()
                        ProgressView()
                    }
                } else if availableBranches.count > 1 {
                    Picker("Branch", selection: $selectedBranch) {
                        ForEach(availableBranches, id: \.self) { Text($0).tag($0) }
                    }
                }
            } footer: {
                if mode == .commit {
                    Text("Commits \(selected.count) file(s) directly to \"\(targetBranch)\".")
                } else {
                    Text("Creates a branch off \"\(branch)\" and opens a pull request into \"\(targetBranch)\".")
                }
            }

            if let errorText {
                Section {
                    Label(errorText, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            loadingBranches = true
            let branches = await fetchBranches()
            availableBranches = branches.isEmpty ? [branch] : branches
            loadingBranches = false
        }
    }

    private func successView(_ url: URL) -> some View {
        ContentUnavailableView {
            Label(mode == .commit ? "Committed" : "Pull Request Opened",
                  systemImage: "checkmark.circle")
        } description: {
            Text(mode == .commit
                 ? "\(checkedDrafts.count) file(s) committed to \"\(targetBranch)\"."
                 : "Your changes are ready to review.")
        } actions: {
            Link(mode == .commit ? "View Commit on GitHub" : "View Pull Request", destination: url)
        }
    }

    private func performCommit() async {
        isCommitting = true
        errorText = nil
        defer { isCommitting = false }
        let files = checkedDrafts.map { (path: $0.ref.path, text: $0.text, blobSHA: $0.blobSHA) }
        let trimmed = message.trimmingCharacters(in: .whitespaces)
        do {
            if let url = try await commit(files, trimmed, mode == .pullRequest, targetBranch) {
                resultURL = url
            } else {
                dismiss()
            }
        } catch GitHubError.conflict {
            errorText = "One of these files changed on GitHub since you loaded it. Nothing was committed — reopen the file to see the latest version, then try again."
        } catch {
            errorText = error.localizedDescription
        }
    }
}
