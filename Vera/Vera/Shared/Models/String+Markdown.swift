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

    func fixMarkdown() -> String {
        var lines = components(separatedBy: "\n")

        // Pass 1: trailing whitespace + smart-quote replacement (outside code fences)
        var inFence = false
        for i in lines.indices {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") || t.hasPrefix("~~~") { inFence.toggle() }
            lines[i] = lines[i].replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
            if !inFence {
                lines[i] = lines[i]
                    .replacingOccurrences(of: "\u{201C}", with: "\"")
                    .replacingOccurrences(of: "\u{201D}", with: "\"")
                    .replacingOccurrences(of: "\u{2018}", with: "'")
                    .replacingOccurrences(of: "\u{2019}", with: "'")
                    .replacingOccurrences(of: "\u{2014}", with: "--")
                    .replacingOccurrences(of: "\u{2013}", with: "-")
            }
        }

        func headingLevel(_ s: String) -> Int {
            guard s.hasPrefix("#") else { return 0 }
            var level = 0
            for c in s { if c == "#" { level += 1 } else { break } }
            guard level <= 6, s.count > level,
                  s[s.index(s.startIndex, offsetBy: level)] == " " else { return 0 }
            return level
        }

        // Pass 2: blank lines around headings (skip front matter and code fences)
        var output: [String] = []
        var inFence2 = false
        var inFrontMatter = false

        for (i, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            if i == 0 && t == "---" { inFrontMatter = true; output.append(line); continue }
            if inFrontMatter {
                output.append(line)
                if t == "---" || t == "..." { inFrontMatter = false }
                continue
            }
            if t.hasPrefix("```") || t.hasPrefix("~~~") {
                inFence2.toggle()
                output.append(line)
                continue
            }
            if inFence2 { output.append(line); continue }

            let level = headingLevel(line)
            if level > 0 {
                // Blank line before heading if previous output line is non-empty content
                if !output.isEmpty && !output[output.count - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                    output.append("")
                }
                output.append(line)
                // Blank line after heading if next line is non-empty and not also a heading
                if i + 1 < lines.count {
                    let next = lines[i + 1]
                    let nextT = next.trimmingCharacters(in: .whitespaces)
                    if !nextT.isEmpty && headingLevel(next) == 0 {
                        output.append("")
                    }
                }
            } else {
                output.append(line)
            }
        }

        // Pass 3: collapse 3+ consecutive blank lines to 2, trim trailing blanks
        var result: [String] = []
        var blankRun = 0
        for line in output {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                blankRun += 1
                if blankRun <= 2 { result.append(line) }
            } else {
                blankRun = 0
                result.append(line)
            }
        }
        while result.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { result.removeLast() }

        return result.joined(separator: "\n")
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
