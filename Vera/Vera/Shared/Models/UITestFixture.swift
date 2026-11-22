#if DEBUG
import Foundation

/// A throwaway folder the UI tests open. Created inside the app's own sandbox, so the same
/// tests run on a simulator and on a physical device (a device can't read the host's /tmp).
/// Debug builds only; launched with `-VeraUITestSeed YES`.
enum UITestFixture {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-VeraUITestSeed")
    }

    /// `-VeraUITestStore`: seed a believable docs repo for App Store screenshots instead.
    static var isStore: Bool {
        ProcessInfo.processInfo.arguments.contains("-VeraUITestStore")
    }

    /// Wipes and recreates the fixture, returning its root.
    static func seed() -> URL? {
        if isStore { return seedStore() }
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

    private static func seedStore() -> URL? {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let root = docs.appendingPathComponent("northwind-docs", isDirectory: true)
        try? fm.removeItem(at: root)
        func put(_ path: String, _ text: String) throws {
            let url = root.appendingPathComponent(path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        do {
            try put("README.md", """
            # Northwind API

            A small, fast **REST API** for orders and inventory. These docs live next to the code, so they change in the same pull request as the behaviour they describe.

            ## Quick start

            1. Clone the repo and run `make dev`.
            2. Open [the architecture notes](docs/architecture.md) for the big picture.
            3. Read the [[Release checklist]] before you tag anything.

            ## Endpoints

            | Verb | Path | Use |
            |------|------|-----|
            | GET | `/orders` | List |
            | POST | `/orders` | Create |
            | GET | `/stock/{sku}` | Stock |

            ## Example

            ```swift
            let client = Northwind(token: env.token)
            let order = try await client.orders.create(sku: "NW-1042", quantity: 3)
            print(order.id)
            ```

            ## Status

            - [x] Authentication
            - [x] Orders
            - [ ] Webhooks
            - [ ] Rate limiting

            > Everything here is plain Markdown in a git repository. No lock-in.

            ## Contributing

            Small, focused pull requests are easiest to review. Add a note to the changelog
            for anything a user could notice.
            """)
            try put("CHANGELOG.md", "# Changelog\n\n## 2.4.0\n\n- Webhook signing\n- Faster stock lookups\n\n## 2.3.1\n\n- Fix pagination off-by-one\n")
            try put("docs/architecture.md", "# Architecture\n\nThe API is a thin layer over a Postgres database.\n\n## Request flow\n\nRouter, auth, handler, store.\n\n## Data model\n\nOrders have line items; line items point at SKUs.\n")
            try put("docs/Release checklist.md", "# Release checklist\n\n- [x] Changelog updated\n- [x] Migrations reviewed\n- [ ] Tag and push\n- [ ] Announce\n")
            try put("config/settings.yaml", "server:\n  port: 8080\n  timeout: 30s\n\ndatabase:\n  host: localhost\n  pool: 10\n\nfeatures:\n  webhooks: false\n  rate_limit: false\n")
            try put("package.json", "{\n  \"name\": \"northwind-api\",\n  \"version\": \"2.4.0\",\n  \"scripts\": {\n    \"dev\": \"node server.js\",\n    \"test\": \"vitest\"\n  }\n}\n")
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
