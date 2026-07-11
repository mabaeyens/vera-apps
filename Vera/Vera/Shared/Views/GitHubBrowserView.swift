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

    /// True when the field holds a different token than what's already saved — connecting
    /// would silently replace it (e.g. switching between a personal and an org account).
    var hasConflictingToken: Bool {
        guard let existing = CredentialStore.load() else { return false }
        return existing != token.trimmingCharacters(in: .whitespaces)
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
        availableBranches = []
        defer { isLoading = false }
        do {
            let c = client()
            let defaultBranch = try await c.defaultBranch()
            branch = defaultBranch
            items = try await c.documentFiles(branch: defaultBranch)
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

    var availableBranches: [String] = []
    var isSwitchingBranch: Bool = false

    func fetchBranches() async {
        guard availableBranches.isEmpty else { return }
        availableBranches = (try? await client().branches()) ?? []
    }

    func switchBranch(_ name: String) async {
        guard name != branch else { return }
        isSwitchingBranch = true
        searchQuery = ""
        searchResults = []
        defer { isSwitchingBranch = false }
        do {
            items = try await client().documentFiles(branch: name)
            branch = name
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// Commit multiple dirty files atomically using the Git Data API.
    /// Single-file, non-PR path falls back to the Contents API for fewer API calls.
    func commitMultiple(
        files: [(path: String, text: String, blobSHA: String)],
        message: String,
        openPR: Bool,
        targetBranch: String
    ) async throws -> URL? {
        let c = client()
        if files.count == 1, let f = files.first, !openPR {
            // Single-file, direct-commit fast path: Contents API (1 call vs 5).
            let urlStr = try await c.commitFile(
                path: f.path, message: message, text: f.text, sha: f.blobSHA, branch: targetBranch
            )
            return urlStr.flatMap(URL.init(string:))
        }
        if openPR {
            // Fork the working branch from the PR's base (targetBranch), not the
            // currently-browsed branch, so the PR diff contains only these files.
            let baseSHA = try await c.headSHA(branch: targetBranch)
            let prBranch = "vera/multi-\(Int(Date().timeIntervalSince1970))"
            try await c.createBranch(name: prBranch, fromSHA: baseSHA)
            try await c.commitFiles(files, message: message, branch: prBranch)
            let prURL = try await c.openPullRequest(
                title: message, body: "Edited in Vera.", head: prBranch, base: targetBranch
            )
            return prURL.flatMap(URL.init(string:))
        } else {
            let urlStr = try await c.commitFiles(files, message: message, branch: targetBranch)
            return URL(string: urlStr)
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
    @Environment(GitHubDraftStore.self) private var draftStore
    @Environment(FileTreeViewModel.self) private var vm
    @State private var model = GitHubBrowserModel()
    @State private var showBranchPicker = false
    @State private var showMultiCommit = false
    @State private var showDeviceAuth = false
    @State private var showTokenFields = false
    @State private var pendingTokenAction: PendingTokenAction?

    private enum PendingTokenAction { case deviceSignIn(String), connect }

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
                if model.isConnected {
                    #if os(iOS)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await model.fetchBranches() }
                            showBranchPicker = true
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.branch")
                                Text(model.branch)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .font(.caption)
                        }
                        .disabled(model.isSwitchingBranch)
                    }
                    #else
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            if model.availableBranches.isEmpty {
                                Label("Loading…", systemImage: "ellipsis")
                            } else {
                                ForEach(model.availableBranches, id: \.self) { name in
                                    Button {
                                        Task { await model.switchBranch(name) }
                                    } label: {
                                        if name == model.branch {
                                            Label(name, systemImage: "checkmark")
                                        } else {
                                            Text(name)
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Branch: \(model.branch)", systemImage: "arrow.branch")
                        }
                        .disabled(model.isSwitchingBranch)
                        .task(id: model.isConnected) {
                            guard model.isConnected else { return }
                            await model.fetchBranches()
                        }
                    }
                    #endif
                    // "Commit N files" button — shown when ≥2 dirty files exist on this branch.
                    // Scoped to the browsed branch so same-path drafts on other branches never
                    // collide into one commit target.
                    let pending = draftStore.repoDrafts(owner: model.owner, repo: model.repo)
                        .filter { $0.ref.branch == model.branch }
                    if pending.count >= 2 {
                        ToolbarItem(placement: .automatic) {
                            Button {
                                showMultiCommit = true
                            } label: {
                                Label("Commit \(pending.count) Files", systemImage: "arrow.up.circle.badge.clock")
                            }
                            .help("Commit all changed files")
                        }
                    }
                }
            }
            .sheet(isPresented: $showBranchPicker) {
                BranchPickerSheet(model: model)
            }
            .sheet(isPresented: $showMultiCommit) {
                let pending = draftStore.repoDrafts(owner: model.owner, repo: model.repo)
                    .filter { $0.ref.branch == model.branch }
                MultiFileCommitSheet(
                    owner: model.owner,
                    repo: model.repo,
                    branch: model.branch,
                    drafts: pending,
                    fetchBranches: { await model.fetchBranches(); return model.availableBranches },
                    commit: { files, message, openPR, targetBranch in
                        let url = try await model.commitMultiple(
                            files: files, message: message, openPR: openPR, targetBranch: targetBranch
                        )
                        // Deregister committed files from draft store, scoped to this branch so
                        // an in-progress draft for the same path on another branch is untouched.
                        draftStore.deregisterPaths(
                            Set(files.map(\.path)), owner: model.owner, repo: model.repo, branch: model.branch
                        )
                        return url
                    }
                )
                #if os(macOS)
                .frame(width: 500, height: 440)
                #endif
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
            // OAuth sign-in section — shown when the GitHub App client ID is configured.
            if !GitHubApp.clientID.isEmpty && model.token.isEmpty {
                Section {
                    Button {
                        showDeviceAuth = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Sign in with GitHub", systemImage: "person.badge.key")
                                .bold()
                            Spacer()
                        }
                    }
                } footer: {
                    Text("Opens github.com to authorize Vera. No password stored — token lives in your device Keychain.")
                }

                Section {
                    Button(showTokenFields ? "Hide token fields" : "Use a personal access token instead") {
                        showTokenFields.toggle()
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            // Token section — always shown if no OAuth client ID; toggled in below it if OAuth is configured.
            if GitHubApp.clientID.isEmpty || !model.token.isEmpty || showTokenFields {
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
            }

            // Repo fields after OAuth sign-in (token is set but owner/repo may be empty).
            if !GitHubApp.clientID.isEmpty && !model.token.isEmpty && !showTokenFields {
                Section("Repository") {
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
                    if model.hasConflictingToken {
                        pendingTokenAction = .connect
                    } else {
                        Task { await connectAndMaybeDismiss() }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if model.isLoading { ProgressView() } else { Text("Browse Files") }
                        Spacer()
                    }
                }
                .disabled(!model.canConnect || model.isLoading)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showDeviceAuth) {
            DeviceAuthSheet { token in
                model.token = token
                showDeviceAuth = false
                if let existing = CredentialStore.load(), existing != token {
                    pendingTokenAction = .deviceSignIn(token)
                } else {
                    CredentialStore.save(token)
                }
            }
            #if os(macOS)
            .frame(width: 400, height: 340)
            #endif
        }
        .alert(
            "Replace Saved GitHub Token?",
            isPresented: Binding(
                get: { pendingTokenAction != nil },
                set: { if !$0 { pendingTokenAction = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                if case .deviceSignIn = pendingTokenAction {
                    model.token = CredentialStore.load() ?? ""
                }
                pendingTokenAction = nil
            }
            Button("Replace") {
                switch pendingTokenAction {
                case .deviceSignIn(let token):
                    CredentialStore.save(token)
                case .connect:
                    Task { await connectAndMaybeDismiss() }
                case nil:
                    break
                }
                pendingTokenAction = nil
            }
        } message: {
            Text("This replaces your saved GitHub token. Repos connected with the old token will stop working until you sign in with it again.")
        }
    }

    /// Connects, then — only if this repo wasn't already saved — dismisses so the user
    /// lands on the sidebar tree to pick a file, instead of staying parked in this sheet's
    /// own file list. Revisiting an already-saved repo (branch switching, content search,
    /// multi-file commit — all only reachable from here) keeps the current in-sheet flow.
    private func connectAndMaybeDismiss() async {
        let wasNew = !RepoListStore.all().contains(
            SavedRepo(owner: model.owner.trimmingCharacters(in: .whitespaces),
                      repo: model.repo.trimmingCharacters(in: .whitespaces))
        )
        await model.connect()
        if wasNew && model.isConnected {
            dismiss()
        }
    }

    /// Opens `source` in the shared editor (same tab/split-view path as the sidebar tree)
    /// and dismisses this sheet, instead of pushing `DocumentView` in the sheet's own
    /// nested navigation stack.
    private func open(_ source: DocumentSource) {
        vm.openInNewTab(source)
        dismiss()
    }

    private var fileList: some View {
        List {
            if model.searchQuery.isEmpty {
                if model.items.isEmpty {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "doc.text",
                        description: Text("No Markdown, text, JSON, or YAML files found in this repository.")
                    )
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
                            Button {
                                open(.gitHub(model.ref(for: GitHubItem(path: result.path))))
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Label {
                                        Text(result.path)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    } icon: {
                                        DocumentFileIcon(name: result.path)
                                    }
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
        .overlay {
            if model.isSwitchingBranch {
                ProgressView()
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func fileRow(_ item: GitHubItem) -> some View {
        // documentFiles() now returns every blob, including images and binaries — match
        // the sidebar tree's icon (so a binary reads as non-interactive at a glance) and
        // make binary rows genuinely non-interactive, instead of a silent no-op tap.
        let isBinary = FileKind.classify(path: item.path) == .binary
        return Button {
            open(.gitHub(model.ref(for: item)))
        } label: {
            Label {
                Text(item.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                DocumentFileIcon(name: item.path)
            }
        }
        .disabled(isBinary)
        .foregroundStyle(isBinary ? .tertiary : .primary)
    }
}

private struct BranchPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: GitHubBrowserModel
    @State private var searchText = ""

    private var filteredBranches: [String] {
        guard !searchText.isEmpty else { return model.availableBranches }
        return model.availableBranches.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredBranches, id: \.self) { name in
                Button {
                    Task {
                        await model.switchBranch(name)
                        dismiss()
                    }
                } label: {
                    HStack {
                        Text(name)
                        Spacer()
                        if name == model.branch {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .searchable(text: $searchText, prompt: "Filter branches")
            .navigationTitle("Switch Branch")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if model.availableBranches.isEmpty {
                    ProgressView()
                }
            }
        }
        .presentationDetents([.medium])
    }
}
