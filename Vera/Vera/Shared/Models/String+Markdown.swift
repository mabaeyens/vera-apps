import Foundation

struct LintWarning: Identifiable, Sendable {
    let id = UUID()
    let line: Int
    let message: String
}

extension String {
    /// Strip inline and block Markdown syntax from the receiver, leaving plain text.
    func strippingMarkdown() -> String {
        var s = self

        // Inline: order matters — longest markers first
        let inlinePatterns: [(String, String)] = [
            (#"\*\*\*(.*?)\*\*\*"#, "$1"),   // bold italic
            (#"\*\*(.*?)\*\*"#,     "$1"),   // bold
            (#"\*(.*?)\*"#,         "$1"),   // italic
            (#"~~(.*?)~~"#,         "$1"),   // strikethrough
            (#"`(.*?)`"#,           "$1"),   // inline code
            (#"\[(.*?)\]\(.*?\)"#,  "$1"),   // link → label
        ]
        for (pattern, replacement) in inlinePatterns {
            s = s.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }

        // Block: strip leading decoration per line
        let blockPatterns: [String] = [
            #"^#{1,6} "#,   // headings
            #"^> "#,        // blockquote
            #"^[-*] "#,     // bullet
            #"^\d+\. "#,    // numbered list
        ]
        let lines = s.components(separatedBy: "\n")
        s = lines.map { line in
            var l = line
            for pattern in blockPatterns {
                l = l.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .anchored])
            }
            return l
        }.joined(separator: "\n")

        return s
    }

    func lintMarkdown() -> [LintWarning] {
        var warnings: [LintWarning] = []
        var inFrontMatter = false
        var inCodeFence = false
        var lastHeadingLevel = 0

        let lines = components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            let lineNum = index + 1

            // Front matter block at document start
            if lineNum == 1 && line.trimmingCharacters(in: .whitespaces) == "---" {
                inFrontMatter = true
                continue
            }
            if inFrontMatter {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed == "---" || trimmed == "..." { inFrontMatter = false }
                continue
            }

            // Code fences
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                inCodeFence.toggle()
                continue
            }
            if inCodeFence { continue }

            // Heading level skip (e.g. h1 → h3)
            if line.first == "#" {
                var level = 0
                for c in line { if c == "#" { level += 1 } else { break } }
                if level >= 1, level <= 6, line.count > level,
                   line[line.index(line.startIndex, offsetBy: level)] == " " {
                    if lastHeadingLevel > 0 && level > lastHeadingLevel + 1 {
                        warnings.append(LintWarning(line: lineNum,
                            message: "Heading skips from h\(lastHeadingLevel) to h\(level)"))
                    }
                    lastHeadingLevel = level
                }
            }

            // Unclosed square brackets on the same line
            let opens = line.filter { $0 == "[" }.count
            let closes = line.filter { $0 == "]" }.count
            if opens > closes {
                warnings.append(LintWarning(line: lineNum, message: "Unclosed '[' bracket"))
            }

            // Image with missing alt text: ![]( ... )
            if line.range(of: #"!\[\]\([^)]*\)"#, options: .regularExpression) != nil {
                warnings.append(LintWarning(line: lineNum, message: "Image missing alt text"))
            }

            if warnings.count >= 500 { break }
        }

        return warnings
    }
}
