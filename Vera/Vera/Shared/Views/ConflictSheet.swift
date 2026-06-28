import SwiftUI

/// Presented when a commit fails with a 409 (stale blob SHA). Lets the user view
/// the current remote version before deciding whether to overwrite it.
struct ConflictSheet: View {
    @Environment(\.dismiss) private var dismiss

    let fileName: String
    let pendingMessage: String
    let pendingOpenPR: Bool
    let fetchRemoteText: () async throws -> String
    let overwrite: () async throws -> URL?

    @State private var isOverwriting = false
    @State private var isLoadingRemote = false
    @State private var remoteText: String?
    @State private var showRemote = false
    @State private var errorText: String?
    @State private var resultURL: URL?

    var body: some View {
        NavigationStack {
            if let resultURL {
                successView(resultURL)
            } else {
                form
            }
        }
    }

    private var form: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Label("File Changed on GitHub", systemImage: "exclamationmark.icloud")
                        .font(.headline)
                    Text("Someone committed to '\(fileName)' after you opened it. You can view their version before deciding.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, Theme.Space.s)
            }

            Section {
                Button {
                    Task { await loadRemote() }
                } label: {
                    HStack {
                        Label("View Their Version", systemImage: "eye")
                        Spacer()
                        if isLoadingRemote { ProgressView() }
                    }
                }
                .disabled(isLoadingRemote || isOverwriting)

                Button(role: .destructive) {
                    Task { await performOverwrite() }
                } label: {
                    HStack {
                        Label("Overwrite With My Version", systemImage: "icloud.and.arrow.up")
                        Spacer()
                        if isOverwriting { ProgressView() }
                    }
                }
                .disabled(isOverwriting || isLoadingRemote)
            } footer: {
                Text("Overwriting replaces the remote file with your edits.")
            }

            if let errorText {
                Section {
                    Label(errorText, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Conflict")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showRemote) {
            if let text = remoteText {
                RemoteVersionSheet(fileName: fileName, text: text)
            }
        }
    }

    private func successView(_ url: URL) -> some View {
        ContentUnavailableView {
            Label("Committed", systemImage: "checkmark.circle")
        } description: {
            Text("Your version is now on GitHub.")
        } actions: {
            Link("View Commit", destination: url)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func loadRemote() async {
        isLoadingRemote = true
        defer { isLoadingRemote = false }
        do {
            remoteText = try await fetchRemoteText()
            showRemote = true
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func performOverwrite() async {
        isOverwriting = true
        defer { isOverwriting = false }
        errorText = nil
        do {
            if let url = try await overwrite() {
                resultURL = url
            } else {
                dismiss()
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private struct RemoteVersionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let fileName: String
    let text: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
            .navigationTitle("Their Version — \(fileName)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
