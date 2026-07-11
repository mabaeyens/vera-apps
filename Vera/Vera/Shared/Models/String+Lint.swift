import Foundation

/// Lightweight, format-agnostic checks for formats other than Markdown (which has its
/// own dedicated `lintMarkdown()` in `String+Markdown.swift`). These are intentionally
/// modest — Vera has no embedded per-language tooling, so there's no real linting for
/// arbitrary source files, only structural validation for JSON/YAML and a few universal
/// hygiene checks.
extension String {
    /// Reports a parse failure, if any. No precise line number — `JSONSerialization`
    /// doesn't reliably expose one, so this deliberately doesn't guess.
    nonisolated func lintJSON() -> [LintWarning] {
        guard !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        do {
            _ = try JSONSerialization.jsonObject(with: Data(utf8))
            return []
        } catch {
            return [LintWarning(line: 1, message: "Invalid JSON: \(error.localizedDescription)")]
        }
    }

    /// Flags lines indented with a tab — YAML indentation must be spaces. This is a
    /// deliberately narrow check, not full YAML structural validation (no YAML parser
    /// dependency exists in the project).
    nonisolated func lintYAML() -> [LintWarning] {
        var warnings: [LintWarning] = []
        for (index, line) in components(separatedBy: "\n").enumerated() where line.hasPrefix("\t") {
            warnings.append(LintWarning(line: index + 1, message: "Line indented with a tab (YAML requires spaces)"))
            if warnings.count >= 500 { break }
        }
        return warnings
    }

    /// Trailing whitespace, missing final newline, mixed tabs/spaces — checks that make
    /// sense for source code and data files. Deliberately NOT applied to Markdown, where
    /// trailing whitespace is meaningful (two trailing spaces = a line break).
    nonisolated func lintGenericHygiene() -> [LintWarning] {
        guard !isEmpty else { return [] }
        var warnings: [LintWarning] = []
        let lines = components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            let lineNum = index + 1
            if line.last?.isWhitespace == true {
                warnings.append(LintWarning(line: lineNum, message: "Trailing whitespace"))
            }
            let leading = line.prefix { $0 == " " || $0 == "\t" }
            if leading.contains(" ") && leading.contains("\t") {
                warnings.append(LintWarning(line: lineNum, message: "Mixed tabs and spaces in indentation"))
            }
            if warnings.count >= 500 { break }
        }
        if !hasSuffix("\n") {
            warnings.append(LintWarning(line: lines.count, message: "Missing final newline"))
        }
        return warnings
    }
}
