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

    /// `-VeraUITestScan`: a folder of files for the sidebar listing, sorting and CSV preview tests.
    static var isScan: Bool {
        ProcessInfo.processInfo.arguments.contains("-VeraUITestScan")
    }

    /// Wipes and recreates the fixture, returning its root.
    static func seed() -> URL? {
        if isStore { return seedStore() }
        if isScan { return seedScan() }
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

    /// Files the listing must show, files it must hide, three files whose name, date and size
    /// each order differently, two folders, and a CSV over the 1 MB preview threshold.
    private static func seedScan() -> URL? {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let root = docs.appendingPathComponent("uitest-scan", isDirectory: true)
        try? fm.removeItem(at: root)
        do {
            try fm.createDirectory(at: root.appendingPathComponent("folder-a"), withIntermediateDirectories: true)
            try fm.createDirectory(at: root.appendingPathComponent("folder-b"), withIntermediateDirectories: true)
            func put(_ name: String, _ data: Data, modified: Date? = nil) throws {
                let url = root.appendingPathComponent(name)
                try data.write(to: url)
                if let modified { try fm.setAttributes([.modificationDate: modified], ofItemAtPath: url.path) }
            }
            func text(_ s: String) -> Data { Data(s.utf8) }

            // Listed: on the allowlist by name or extension, or text by content.
            try put("Makefile", text("all:\n\techo hi\n"))
            try put("app.conf", text("port = 5432\n"))
            try put(".env", text("KEY=value\n"))
            try put("odd.xyz", text("plain text with an extension nobody knows\n"))
            // Latin-1 bytes: a lone 0xF3 is not valid UTF-8.
            try put("legacy.cfg", "[main]\nmensaje = Configuraci\u{F3}n\n".data(using: .isoLatin1) ?? Data())

            // Hidden: known binary extensions, and an unknown extension holding NUL bytes.
            try put("watch.pbw", Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00]))
            try put("book.epub", Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00]))
            try put("doc.pdf", text("%PDF-1.4\n"))
            try put("blob.dat", Data([0x00, 0x01, 0x02, 0x00, 0xFF, 0xFE, 0x00, 0x00]))

            // Sort: name alpha<bravo<charlie, date bravo newest, size bravo<charlie<alpha.
            let day: TimeInterval = 86_400
            try put("alpha.txt", text(String(repeating: "a", count: 300)), modified: Date(timeIntervalSinceNow: -900 * day))
            try put("bravo.txt", text(String(repeating: "b", count: 100)), modified: Date(timeIntervalSinceNow: -10 * day))
            try put("charlie.txt", text(String(repeating: "c", count: 200)), modified: Date(timeIntervalSinceNow: -400 * day))

            // CSV: over 1 MB, one line per row with a zero-padded marker so rows can't prefix-match.
            var big = "id,payload\n"
            for n in 1...12_000 {
                big += String(format: "ROW-%05d,", n) + String(repeating: "x", count: 90) + "\n"
            }
            try put("big.csv", text(big))
            try put("small.csv", text("id,payload\nROW-00001,x\n"))
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
