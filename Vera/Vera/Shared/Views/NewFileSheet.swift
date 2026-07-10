import SwiftUI

/// Where a new file gets created — a local/iCloud folder, or the root of a connected
/// GitHub repo (committed directly, no subfolder picker — matches the local picker's
/// top-level-only scope).
private enum NewFileLocation: Hashable {
    case root
    case folder(URL)
    case gitHub(SavedRepo)
}

struct NewFileSheet: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    let onCreated: (DocumentSource) -> Void

    @State private var filename = ""
    @State private var format: DocumentFormat = .markdown
    @State private var location: NewFileLocation = .root
    @State private var isCreating = false
    @State private var errorMessage: String?
    @FocusState private var fieldFocused: Bool

    private var topLevelFolders: [(name: String, url: URL)] {
        vm.roots.compactMap {
            if case .folder(_, let name, let url, _) = $0 {
                return (name, url)
            }
            return nil
        }
    }

    private var savedRepos: [SavedRepo] { RepoListStore.all() }

    var body: some View {
        #if os(iOS)
        NavigationStack { form.navigationTitle("New File").navigationBarTitleDisplayMode(.inline).toolbar { iOSToolbar } }
        #else
        form.padding(20).frame(width: 360)
        #endif
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("File name").font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    TextField("untitled", text: $filename)
                        .textFieldStyle(.roundedBorder)
                        .focused($fieldFocused)
                        #if os(iOS)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        #endif
                    Text(".\(format.defaultExtension)").foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Format").font(.subheadline).foregroundStyle(.secondary)
                Picker("Format", selection: $format) {
                    ForEach(DocumentFormat.allCases, id: \.self) { format in
                        Text(format.label).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }

            if !topLevelFolders.isEmpty || !savedRepos.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Location").font(.subheadline).foregroundStyle(.secondary)
                    Picker("Location", selection: $location) {
                        Text("Root folder").tag(NewFileLocation.root)
                        ForEach(topLevelFolders, id: \.url) { folder in
                            Text(folder.name).tag(NewFileLocation.folder(folder.url))
                        }
                        if !savedRepos.isEmpty {
                            Divider()
                            ForEach(savedRepos) { repo in
                                Text(repo.displayName).tag(NewFileLocation.gitHub(repo))
                            }
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if let error = errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            #if os(macOS)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(filename.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            }
            #endif

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .task { fieldFocused = true }
    }

    #if os(iOS)
    @ToolbarContentBuilder
    private var iOSToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Create") { create() }
                .disabled(filename.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
        }
    }
    #endif

    private func create() {
        let trimmed = filename.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isCreating = true
        errorMessage = nil
        Task {
            do {
                let source: DocumentSource
                switch location {
                case .root:
                    guard let folder = vm.rootURL else {
                        errorMessage = "No local folder is open. Pick a GitHub repo as the location instead."
                        isCreating = false
                        return
                    }
                    source = .file(try await vm.createFile(named: trimmed, in: folder, format: format))
                case .folder(let folder):
                    source = .file(try await vm.createFile(named: trimmed, in: folder, format: format))
                case .gitHub(let repo):
                    source = try await createInGitHub(repo, name: trimmed)
                }
                dismiss()
                onCreated(source)
            } catch CocoaError.fileWriteFileExists {
                errorMessage = "A file with that name already exists."
                isCreating = false
            } catch {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }

    /// Commits an empty new file to the repo's default branch. `sha: nil` tells
    /// GitHub's Contents API to create rather than update.
    private func createInGitHub(_ repo: SavedRepo, name: String) async throws -> DocumentSource {
        guard let token = CredentialStore.load() else { throw GitHubError.noToken }
        let client = GitHubClient(owner: repo.owner, repo: repo.repo, token: token)
        let branch = try await client.defaultBranch()
        let path = name.hasSuffix(".\(format.defaultExtension)") ? name : "\(name).\(format.defaultExtension)"
        try await client.commitFile(path: path, message: "Create \(path)", text: "", sha: nil, branch: branch)
        return .gitHub(GitHubFileRef(owner: repo.owner, repo: repo.repo, path: path, branch: branch))
    }
}
