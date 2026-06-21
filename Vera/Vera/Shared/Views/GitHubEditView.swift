import SwiftUI

/// Light edit + commit for a GitHub Markdown file. (Spec C3.)
///
/// You can commit straight to the branch you're viewing, or open a pull request
/// (Vera creates a branch, commits there, and opens the PR). No merge-conflict UI:
/// commits use the file's blob SHA, so GitHub safely rejects a stale edit.
struct GitHubEditView: View {
    @Environment(\.dismiss) private var dismiss

    let model: GitHubBrowserModel
    let item: GitHubItem
    /// Called with the latest committed text so the read view can refresh in place
    /// (only for direct commits — a PR doesn't change the viewed branch).
    var onCommitted: (String) -> Void

    enum Mode: String, CaseIterable, Identifiable {
        case commit = "Commit"
        case pullRequest = "Pull Request"
        var id: String { rawValue }
    }

    @State private var text: String = ""
    @State private var sha: String = ""
    @State private var message: String = ""
    @State private var mode: Mode = .commit

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var resultURL: URL?

    private var canSave: Bool {
        !isLoading && !isSaving && !sha.isEmpty
            && !message.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if let resultURL {
                    successView(resultURL)
                } else if isLoading {
                    ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    editor
                }
            }
            .navigationTitle(item.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(resultURL == nil ? "Cancel" : "Done") { dismiss() }
                }
                if resultURL == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Button(mode == .commit ? "Commit" : "Open PR") {
                                Task { await save() }
                            }
                            .disabled(!canSave)
                        }
                    }
                }
            }
        }
        .task { await load() }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .padding(Theme.Space.s)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif

            Divider()

            VStack(spacing: Theme.Space.s) {
                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                TextField("Commit message", text: $message)
                    .textFieldStyle(.roundedBorder)
                Picker("Destination", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(mode == .commit
                     ? "Commits directly to \(branchLabel)."
                     : "Creates a branch off \(branchLabel) and opens a pull request.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Space.m)
            .background(.regularMaterial)
        }
    }

    private var branchLabel: String {
        model.branch.isEmpty ? "the default branch" : "“\(model.branch)”"
    }

    private func successView(_ url: URL) -> some View {
        ContentUnavailableView {
            Label(mode == .commit ? "Committed" : "Pull Request Opened",
                  systemImage: "checkmark.circle")
        } description: {
            Text(mode == .commit
                 ? "Your changes are on \(branchLabel)."
                 : "Your changes are ready to review.")
        } actions: {
            Link(mode == .commit ? "View Commit on GitHub" : "View Pull Request", destination: url)
        }
    }

    private func load() async {
        do {
            let v = try await model.fileVersion(of: item)
            text = v.text
            sha = v.sha
            message = "Update \(item.name)"
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }

    private func save() async {
        isSaving = true
        errorText = nil
        defer { isSaving = false }
        let msg = message.trimmingCharacters(in: .whitespaces)
        do {
            let urlString: String?
            switch mode {
            case .commit:
                urlString = try await model.commitDirect(item, text: text, sha: sha, message: msg)
                onCommitted(text)
            case .pullRequest:
                urlString = try await model.commitViaPullRequest(item, text: text, sha: sha, message: msg)
            }
            if let urlString, let url = URL(string: urlString) {
                resultURL = url
            } else {
                dismiss()
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
