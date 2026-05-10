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
    var anchorPoint: CGPoint? = nil

    enum SaveState { case saved, saving, error(String) }

    let url: URL
    private var saveTask: Task<Void, Never>?

    init(url: URL) {
        self.url = url
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            rawText = try DocumentStore.read(url)
        } catch {
            rawText = ""
        }
    }

    func enterEditMode(tapY: CGFloat = 0, viewHeight: CGFloat = 0) {
        anchorPoint = CGPoint(x: 0, y: tapY)
        mode = .editing
    }

    func exitEditMode() {
        mode = .viewing
        anchorPoint = nil
    }

    func textDidChange() {
        saveState = .saving
        scheduleSave()
    }

    // MARK: - Private

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            self.flush()
        }
    }

    private func flush() {
        do {
            try DocumentStore.write(url, content: rawText)
            saveState = .saved
        } catch {
            saveState = .error(error.localizedDescription)
        }
    }
}
