#if DEBUG
import Foundation

/// A throwaway folder the UI tests open. Created inside the app's own sandbox, so the same
/// tests run on a simulator and on a physical device (a device can't read the host's /tmp).
/// Debug builds only; launched with `-VeraUITestSeed YES`.
enum UITestFixture {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-VeraUITestSeed")
    }

    /// Wipes and recreates the fixture, returning its root.
    static func seed() -> URL? {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let root = docs.appendingPathComponent("uitest-fixture", isDirectory: true)
        try? fm.removeItem(at: root)
        do {
            try fm.createDirectory(at: root.appendingPathComponent("notes"), withIntermediateDirectories: true)
            try """
            # Welcome

            Intro paragraph with a [link to other](other.md#second-part) and a [[Ideas]] wikilink.

            Jump to [a late section](long.md#section-35).

            ## First Part

            Some text.

            ## Second Part

            More text.
            """.write(to: root.appendingPathComponent("welcome.md"), atomically: true, encoding: .utf8)
            try "# Other\n\nBody\n\n## Second Part\n\nTarget.\n"
                .write(to: root.appendingPathComponent("other.md"), atomically: true, encoding: .utf8)
            var long = "# Long\n\n"
            for n in 1...40 {
                long += "## Section \(n)\n\n"
                for line in 1...10 { long += "Filler line \(line) of section \(n), enough text to take up room.\n\n" }
            }
            try long.write(to: root.appendingPathComponent("long.md"), atomically: true, encoding: .utf8)
            try "start\n\n".write(to: root.appendingPathComponent("scratch.md"), atomically: true, encoding: .utf8)
            try "# Ideas\n\n- one\n"
                .write(to: root.appendingPathComponent("notes/Ideas.md"), atomically: true, encoding: .utf8)
        } catch {
            return nil
        }
        return root
    }

    /// `-VeraUITestExternalEdit <seconds>`: after that delay, rewrite welcome.md on disk from
    /// outside the editor, the way another app or an iCloud sync would. Lets a test make the
    /// open buffer stale without needing host access to the app's sandbox.
    static func scheduleExternalEdit(in root: URL) {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-VeraUITestExternalEdit"), args.indices.contains(i + 1),
              let delay = Double(args[i + 1]) else { return }
        Task.detached {
            try? await Task.sleep(for: .seconds(delay))
            let file = root.appendingPathComponent("welcome.md")
            try? "# Welcome\n\nEXTERNAL EDIT\n".write(to: file, atomically: true, encoding: .utf8)
        }
    }
}
#endif
