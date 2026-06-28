import SwiftUI

/// Commit the current editor text to GitHub — straight to the branch, or as a new
/// branch + pull request. Presented from `DocumentView` when editing a GitHub file.
struct GitHubCommitSheet: View {
    @Environment(\.dismiss) private var dismiss

    let fileName: String
    let branch: String
    /// Fetches the branch list for the picker; returns empty on failure (picker hidden).
    let fetchBranches: () async -> [String]
    /// Called when the commit fails with a 409 conflict; the sheet dismisses itself first.
    let onConflict: ((_ message: String, _ openPR: Bool, _ targetBranch: String) -> Void)?
    /// Performs the commit; returns the GitHub URL to show (commit or PR), if any.
    let commit: (_ message: String, _ openPR: Bool, _ targetBranch: String) async throws -> URL?

    enum Mode: String, CaseIterable, Identifiable {
        case commit = "Commit"
        case pullRequest = "Pull Request"
        var id: String { rawValue }
    }

    @State private var message: String = ""
    @State private var mode: Mode = .commit
    @State private var selectedBranch: String = ""
    @State private var availableBranches: [String] = []
    @State private var loadingBranches = false
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var resultURL: URL?

    private var canSave: Bool {
        !isSaving && !message.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var targetBranch: String {
        selectedBranch.isEmpty ? branch : selectedBranch
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
            .navigationTitle("Commit")
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
        .onAppear {
            if message.isEmpty { message = "Update \(fileName)" }
            if selectedBranch.isEmpty { selectedBranch = branch }
        }
    }

    private var form: some View {
        Form {
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
                    Text("Commits directly to \"\(targetBranch)\".")
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
                 ? "Your changes are on \"\(targetBranch)\"."
                 : "Your changes are ready to review.")
        } actions: {
            Link(mode == .commit ? "View Commit on GitHub" : "View Pull Request", destination: url)
        }
    }

    private func save() async {
        isSaving = true
        errorText = nil
        defer { isSaving = false }
        let trimmed = message.trimmingCharacters(in: .whitespaces)
        do {
            if let url = try await commit(trimmed, mode == .pullRequest, targetBranch) {
                resultURL = url
            } else {
                dismiss()
            }
        } catch GitHubError.conflict {
            onConflict?(trimmed, mode == .pullRequest, targetBranch)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
