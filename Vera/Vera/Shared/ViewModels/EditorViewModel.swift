import Foundation
import Observation

enum EditorMode { case viewing, editing }

@Observable
@MainActor
final class EditorViewModel {
    var mode: EditorMode = .viewing
    var rawText: String = ""
    var isLoading = false
    var saveState: SaveState = .saved
    var anchorFraction: CGFloat? = nil
    var readingScrollFraction: CGFloat = 0
    var insertAtCursor: ((String) -> Void)? = nil
    var wrapSelection: ((String, String) -> Void)? = nil
    var stripSelection: (() -> Void)? = nil
    var atlasRequested = false
    var lintResults: [LintWarning] = []

    enum SaveState { case saved, saving, error(String) }

    let url: URL
    private var saveTask: Task<Void, Never>?
    private var lintTask: Task<Void, Never>?

    init(url: URL) {
        self.url = url
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            rawText = try await DocumentStore.read(url)
        } catch {
            // File may be an iCloud item mid-download; poll until available (up to 15 s).
            for _ in 0..<15 {
                try? await Task.sleep(for: .seconds(1))
                let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                    .ubiquitousItemDownloadingStatus
                if status == .current || status == .downloaded {
                    rawText = (try? await DocumentStore.read(url)) ?? ""
                    return
                }
            }
            rawText = ""
        }
    }

    func enterEditMode(tapY: CGFloat = 0, viewHeight: CGFloat = 0) {
        if viewHeight > 0 {
            anchorFraction = tapY / viewHeight
        } else {
            // Toolbar Edit button: use the current reading scroll position
            anchorFraction = readingScrollFraction > 0 ? readingScrollFraction : nil
        }
        mode = .editing
    }

    func exitEditMode() {
        mode = .viewing
        anchorFraction = nil
    }

    func insertSnippet(_ snippet: String) {
        if let insert = insertAtCursor {
            insert(snippet)
        } else {
            rawText += "\n\(snippet)"
            textDidChange()
        }
    }

    func stripAtCursor() {
        stripSelection?()
    }

    func wrapOrInsert(_ syntax: String, prefix: String, suffix: String) {
        if let wrap = wrapSelection {
            wrap(prefix, suffix)
        } else {
            insertSnippet(syntax)
        }
    }

    func textDidChange() {
        saveState = .saving
        scheduleSave()
        scheduleLint()
    }

    // MARK: - Private

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            await self.flush()
        }
    }

    private func scheduleLint() {
        let enabled = UserDefaults.standard.object(forKey: "linterEnabled") == nil
            ? true : UserDefaults.standard.bool(forKey: "linterEnabled")
        guard enabled else {
            lintResults = []
            return
        }
        lintTask?.cancel()
        let snapshot = rawText
        lintTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let results = snapshot.lintMarkdown()
            guard !Task.isCancelled else { return }
            self?.lintResults = results
        }
    }

    private func flush() async {
        do {
            try await DocumentStore.write(url, content: rawText)
            saveState = .saved
        } catch {
            saveState = .error(error.localizedDescription)
        }
    }
}
