import SwiftUI
import MarkdownUI

@MainActor
@Observable
final class GitHubBrowserModel {
    var token: String = CredentialStore.load() ?? ""
    var owner: String = UserDefaults.standard.string(forKey: "github.lastOwner") ?? ""
    var repo: String = UserDefaults.standard.string(forKey: "github.lastRepo") ?? ""

    var items: [GitHubItem] = []
    var branch: String = ""
    var isConnected = false
    var isLoading = false
    var errorText: String?

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
            UserDefaults.standard.set(cleanOwner, forKey: "github.lastOwner")
            UserDefaults.standard.set(cleanRepo, forKey: "github.lastRepo")
            isConnected = true
        } catch {
            errorText = error.localizedDescription
        }
    }

    func contents(of item: GitHubItem) async throws -> String {
        try await client().fileContents(path: item.path)
    }

    func latestCommit(of item: GitHubItem) async throws -> GitHubCommit? {
        try await client().latestCommit(path: item.path)
    }

    func diff(of item: GitHubItem, from base: String, to head: String) async throws -> String? {
        try await client().diff(path: item.path, from: base, to: head)
    }

    // MARK: - Edit (Spec C3)

    /// Current text + blob SHA on the active branch, for editing.
    func fileVersion(of item: GitHubItem) async throws -> (text: String, sha: String) {
        try await client().fileVersion(path: item.path, ref: branch.isEmpty ? "HEAD" : branch)
    }

    /// Commit edited text straight to the active branch. Returns the commit URL.
    func commitDirect(_ item: GitHubItem, text: String, sha: String, message: String) async throws -> String? {
        try await client().commitFile(path: item.path, message: message, text: text, sha: sha, branch: branch)
    }

    /// Create a new branch off the active branch, commit the edit there, and open a PR.
    /// Returns the PR URL.
    func commitViaPullRequest(_ item: GitHubItem, text: String, sha: String, message: String) async throws -> String? {
        let c = client()
        let base = branch.isEmpty ? try await c.defaultBranch() : branch
        let head = "vera/\(slug(item.name))-\(Int(Date().timeIntervalSince1970))"
        let baseSHA = try await c.headSHA(branch: base)
        try await c.createBranch(name: head, fromSHA: baseSHA)
        try await c.commitFile(path: item.path, message: message, text: text, sha: sha, branch: head)
        return try await c.openPullRequest(
            title: message,
            body: "Edited in Vera.",
            head: head,
            base: base
        )
    }

    private func slug(_ s: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        let lowered = s.lowercased().replacingOccurrences(of: " ", with: "-")
        return String(lowered.unicodeScalars.filter { allowed.contains($0) }).prefix(40).description
    }
}

struct GitHubBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = GitHubBrowserModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.isConnected {
                    fileList
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
        }
    }

    private var connectForm: some View {
        Form {
            Section {
                if model.token.isEmpty {
                    SecureField("Fine-grained token (ghp_…)", text: $model.token)
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
                    .textContentType(.username)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
                TextField("Repository (e.g. vera-apps)", text: $model.repo)
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
            if model.items.isEmpty {
                ContentUnavailableView("No Markdown Files", systemImage: "doc.text", description: Text("This repository has no .md files."))
            } else {
                ForEach(model.items) { item in
                    NavigationLink {
                        GitHubReadView(model: model, item: item)
                    } label: {
                        Label(item.path, systemImage: "doc.text")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
    }
}

private struct GitHubReadView: View {
    let model: GitHubBrowserModel
    let item: GitHubItem
    @State private var content: String?
    @State private var errorText: String?

    // Spec C2 — "what changed since you last looked".
    @State private var latest: GitHubCommit?
    @State private var lastSeen: String?
    @State private var showDiff = false

    // Spec C3 — light edit + commit.
    @State private var showEdit = false

    /// The file has changed since the user last viewed it (and we have a baseline).
    private var hasChanges: Bool {
        guard let latest, let lastSeen else { return false }
        return latest.sha != lastSeen
    }

    var body: some View {
        Group {
            if let content {
                ScrollView {
                    Markdown(content)
                        .padding(Theme.Space.l)
                }
            } else if let errorText {
                ContentUnavailableView {
                    Label("Couldn't Load File", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorText)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(item.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showDiff = true
                    } label: {
                        Label("What Changed", systemImage: "plus.forwardslash.minus")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEdit = true
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
                .disabled(content == nil)
            }
        }
        .sheet(isPresented: $showDiff, onDismiss: refreshSeen) {
            if let latest, let lastSeen {
                GitHubDiffView(model: model, item: item, base: lastSeen, head: latest)
            }
        }
        .sheet(isPresented: $showEdit) {
            GitHubEditView(model: model, item: item) { newText in
                content = newText
            }
        }
        .task {
            await load()
        }
    }

    private func load() async {
        do { content = try await model.contents(of: item) }
        catch { errorText = error.localizedDescription }

        lastSeen = RepoSeenStore.lastSeen(owner: model.owner, repo: model.repo, path: item.path)
        latest = try? await model.latestCommit(of: item)
        // First visit: record the baseline silently so future visits can diff.
        if lastSeen == nil, let sha = latest?.sha {
            RepoSeenStore.markSeen(owner: model.owner, repo: model.repo, path: item.path, sha: sha)
            lastSeen = sha
        }
    }

    /// After the diff sheet closes it has marked the latest commit as seen — reflect that.
    private func refreshSeen() {
        lastSeen = RepoSeenStore.lastSeen(owner: model.owner, repo: model.repo, path: item.path)
    }
}
