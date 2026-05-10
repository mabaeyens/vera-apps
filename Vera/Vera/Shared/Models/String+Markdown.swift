import Foundation

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
}
