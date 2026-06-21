import SwiftUI

/// Commit the current editor text to GitHub — straight to the branch, or as a new
/// branch + pull request. Presented from `DocumentView` when editing a GitHub file.
/// (Spec C3; the editing surface itself is the shared DocumentView, for full parity
/// with iCloud files.)
struct GitHubCommitSheet: View {
    @Environment(\.dismiss) private var dismiss

    let fileName: String
    let branch: String
    /// Performs the commit; returns the GitHub URL to show (commit or PR), if any.
    let commit: (_ message: String, _ openPR: Bool) async throws -> URL?

    enum Mode: String, CaseIterable, Identifiable {
        case commit = "Commit"
        case pullRequest = "Pull Request"
        var id: String { rawValue }
    }

    @State private var message: String = ""
    @State private var mode: Mode = .commit
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var resultURL: URL?

    private var canSave: Bool {
        !isSaving && !message.trimmingCharacters(in: .whitespaces).isEmpty
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
        .onAppear { if message.isEmpty { message = "Update \(fileName)" } }
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
            } footer: {
                Text(mode == .commit
                     ? "Commits directly to “\(branch)”."
                     : "Creates a branch off “\(branch)” and opens a pull request.")
            }
            if let errorText {
                Section {
                    Label(errorText, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func successView(_ url: URL) -> some View {
        ContentUnavailableView {
            Label(mode == .commit ? "Committed" : "Pull Request Opened",
                  systemImage: "checkmark.circle")
        } description: {
            Text(mode == .commit
                 ? "Your changes are on “\(branch)”."
                 : "Your changes are ready to review.")
        } actions: {
            Link(mode == .commit ? "View Commit on GitHub" : "View Pull Request", destination: url)
        }
    }

    private func save() async {
        isSaving = true
        errorText = nil
        defer { isSaving = false }
        do {
            if let url = try await commit(message.trimmingCharacters(in: .whitespaces), mode == .pullRequest) {
                resultURL = url
            } else {
                dismiss()
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
