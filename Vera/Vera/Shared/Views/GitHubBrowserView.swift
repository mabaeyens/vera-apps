import SwiftUI

@MainActor
@Observable
final class GitHubBrowserModel {
    var token: String = CredentialStore.load() ?? ""
    var owner: String = UserDefaults.standard.string(forKey: Defaults.Key.githubLastOwner) ?? ""
    var repo: String = UserDefaults.standard.string(forKey: Defaults.Key.githubLastRepo) ?? ""

    var items: [GitHubItem] = []
    var branch: String = ""
    var isConnected = false
    var isLoading = false
    var errorText: String?

    var searchQuery: String = ""
    var searchResults: [CodeSearchResult] = []
    var isSearching: Bool = false
    var searchError: String?

    var filteredItems: [GitHubItem] {
        guard !searchQuery.isEmpty else { return items }
        return items.filter { $0.path.localizedCaseInsensitiveContains(searchQuery) }
    }

    var contentOnlyResults: [CodeSearchResult] {
        let filePaths = Set(filteredItems.map(\.path))
        return searchResults.filter { !filePaths.contains($0.path) }
    }

    func searchCode(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            searchError = nil
            return
        }
        isSearching = true
        searchError = nil
        do {
            searchResults = try await client().searchCode(query: query)
        } catch GitHubError.badResponse(let code) where code == 403 || code == 429 {
            searchError = "Search rate limit reached — try again in a moment."
            searchResults = []
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    var canConnect: Bool {
        !token.trimmingCharacters(in: .whitespaces).isEmpty
            && !owner.trimmingCharacters(in: .whitespaces).isEmpty
            && !repo.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func client() -> GitHubClient {
        GitHubClient(
            owner: owner.trimmingCharacters(in: .whitespaces),
            repo: repo.trimmingCharacters(in: .whitespaces),
            token: token.trimmingCharacters(in: .whitespaces)
        )
    }

    func connect() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            let c = client()
            let defaultBranch = try await c.defaultBranch()
            branch = defaultBranch
            items = try await c.markdownFiles(branch: defaultBranch)
            // Persist the token (Keychain, device-local) and the repo. The repo list
            // syncs across devices via iCloud; the token never does.
            let cleanOwner = owner.trimmingCharacters(in: .whitespaces)
            let cleanRepo = repo.trimmingCharacters(in: .whitespaces)
            CredentialStore.save(token.trimmingCharacters(in: .whitespaces))
            RepoListStore.add(SavedRepo(owner: cleanOwner, repo: cleanRepo))
            UserDefaults.standard.set(cleanOwner, forKey: Defaults.Key.githubLastOwner)
            UserDefaults.standard.set(cleanRepo, forKey: Defaults.Key.githubLastRepo)
            isConnected = true
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// Build a source ref for opening `item` in the shared DocumentView editor.
    func ref(for item: GitHubItem) -> GitHubFileRef {
        GitHubFileRef(
            owner: owner.trimmingCharacters(in: .whitespaces),
            repo: repo.trimmingCharacters(in: .whitespaces),
            path: item.path,
            branch: branch
        )
    }
}

struct GitHubBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = GitHubBrowserModel()

    /// When opened from a saved repo in the sidebar, pre-fill and auto-connect.
    private let initialRepo: SavedRepo?

    init(initialRepo: SavedRepo? = nil) {
        self.initialRepo = initialRepo
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.isConnected {
                    fileList
                        .searchable(text: $model.searchQuery, prompt: "Filename or content…")
                        .task(id: model.searchQuery) {
                            guard !model.searchQuery.isEmpty else {
                                model.searchResults = []
                                model.isSearching = false
                                return
                            }
                            try? await Task.sleep(for: .milliseconds(800))
                            guard !Task.isCancelled else { return }
                            await model.searchCode(model.searchQuery)
                        }
                } else {
                    connectForm
                }
            }
            .navigationTitle(model.isConnected ? "\(model.owner)/\(model.repo)" : "Open from GitHub")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                guard let initialRepo, !model.isConnected else { return }
                model.owner = initialRepo.owner
                model.repo = initialRepo.repo
                // Connect straight away if we already have a token on this device;
                // otherwise the form shows pre-filled so the user just adds the token.
                if !model.token.isEmpty {
                    await model.connect()
                }
            }
        }
    }

    private var connectForm: some View {
        Form {
            Section {
                if model.token.isEmpty {
                    SecureField("Fine-grained token (ghp_…)", text: $model.token)
                        .accessibilityLabel("GitHub fine-grained token")
                } else {
                    HStack {
                        Label("Token saved", systemImage: "key.fill")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Replace") { model.token = "" }
                            .font(.footnote)
                    }
                }
                TextField("Owner (e.g. mabaeyens)", text: $model.owner)
                    .accessibilityLabel("Repository owner")
                    .textContentType(.username)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
                TextField("Repository (e.g. vera-apps)", text: $model.repo)
                    .accessibilityLabel("Repository name")
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
            } header: {
                Text("Connect a repository")
            } footer: {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text("Vera talks directly to GitHub with your token — nothing is sent anywhere else. The token is stored in your device Keychain.")
                    if let url = URL(string: "https://github.com/settings/personal-access-tokens/new") {
                        Link("Create a fine-grained token (Contents: Read, or Read and Write to edit)…", destination: url)
                    }
                }
            }

            if let error = model.errorText {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await model.connect() }
                } label: {
                    HStack {
                        Spacer()
                        if model.isLoading { ProgressView() } else { Text("Browse Markdown") }
                        Spacer()
                    }
                }
                .disabled(!model.canConnect || model.isLoading)
            }
        }
        .formStyle(.grouped)
    }

    private var fileList: some View {
        List {
            if model.searchQuery.isEmpty {
                if model.items.isEmpty {
                    ContentUnavailableView("No Markdown Files", systemImage: "doc.text", description: Text("This repository has no .md files."))
                } else {
                    ForEach(model.items) { item in fileRow(item) }
                }
            } else {
                let nameMatches = model.filteredItems
                if !nameMatches.isEmpty {
                    Section("Files") {
                        ForEach(nameMatches) { item in fileRow(item) }
                    }
                }
                Section("Content") {
                    if model.isSearching {
                        Label("Searching…", systemImage: "magnifyingglass")
                            .foregroundStyle(.secondary)
                    } else if let err = model.searchError {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else if model.contentOnlyResults.isEmpty {
                        Text("No content matches")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.contentOnlyResults) { result in
                            NavigationLink {
                                DocumentView(source: .gitHub(model.ref(for: GitHubItem(path: result.path))))
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Label(result.path, systemImage: "doc.text")
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    if let fragment = result.fragment {
                                        Text(fragment)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func fileRow(_ item: GitHubItem) -> some View {
        NavigationLink {
            DocumentView(source: .gitHub(model.ref(for: item)))
        } label: {
            Label(item.path, systemImage: "doc.text")
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
