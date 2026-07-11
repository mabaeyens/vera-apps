import SwiftUI
import MarkdownUI

// MARK: - Document segment model

private enum DocSegment {
    case prose(String)
    case codeBlock(language: String?, content: String)
    case table(headers: [String], rows: [[String]])
}

private func parseDocSegments(_ raw: String) -> [DocSegment] {
    guard let regex = try? NSRegularExpression(
        pattern: #"```([^\n]*)\n([\s\S]*?)```"#
    ) else { return splitDocTables(raw) }

    let ns = raw as NSString
    var segments: [DocSegment] = []
    var lastEnd = 0

    for match in regex.matches(in: raw, range: NSRange(location: 0, length: ns.length)) {
        let before = NSRange(location: lastEnd, length: match.range.location - lastEnd)
        if before.length > 0 {
            segments.append(contentsOf: splitDocTables(ns.substring(with: before)))
        }
        let langStr = match.range(at: 1).location != NSNotFound
            ? ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            : ""
        let codeStr = match.range(at: 2).location != NSNotFound
            ? ns.substring(with: match.range(at: 2))
            : ""
        segments.append(.codeBlock(language: langStr.isEmpty ? nil : langStr, content: codeStr))
        lastEnd = match.range.location + match.range.length
    }
    if lastEnd < ns.length {
        segments.append(contentsOf: splitDocTables(ns.substring(from: lastEnd)))
    }
    return segments.isEmpty ? [.prose(raw)] : segments
}

private func splitDocTables(_ text: String) -> [DocSegment] {
    let lines = text.components(separatedBy: "\n")
    var result: [DocSegment] = []
    var buffer: [String] = []
    var i = 0

    while i < lines.count {
        if i + 1 < lines.count,
           isDocTableRow(lines[i]),
           isDocTableSeparator(lines[i + 1]) {
            let prose = buffer.joined(separator: "\n")
            if !prose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(.prose(prose))
            }
            buffer = []
            let headers = docTableRowCells(lines[i])
            i += 2
            var rows: [[String]] = []
            while i < lines.count && isDocTableRow(lines[i]) {
                rows.append(docTableRowCells(lines[i]))
                i += 1
            }
            if !headers.isEmpty {
                result.append(.table(headers: headers, rows: rows))
            }
        } else {
            buffer.append(lines[i])
            i += 1
        }
    }
    let remaining = buffer.joined(separator: "\n")
    if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        result.append(.prose(remaining))
    }
    return result.isEmpty ? [.prose(text)] : result
}

private func isDocTableRow(_ line: String) -> Bool {
    line.trimmingCharacters(in: .whitespaces).contains("|")
}

private func isDocTableSeparator(_ line: String) -> Bool {
    let t = line.trimmingCharacters(in: .whitespaces)
    guard t.contains("|"), t.contains("-") else { return false }
    let stripped = t
        .replacingOccurrences(of: "|", with: "")
        .replacingOccurrences(of: "-", with: "")
        .replacingOccurrences(of: ":", with: "")
        .replacingOccurrences(of: " ", with: "")
    return stripped.isEmpty
}

private func docTableRowCells(_ line: String) -> [String] {
    var cells = line.trimmingCharacters(in: .whitespaces).components(separatedBy: "|")
    if cells.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { cells.removeFirst() }
    if cells.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { cells.removeLast() }
    return cells.map { $0.trimmingCharacters(in: .whitespaces) }
}

// MARK: - MarkdownUI theme for Vera

extension MarkdownUI.Theme {
    static func vera(fontSize: CGFloat) -> Self {
        .gitHub
            .text {
                FontSize(fontSize)
                ForegroundColor(.primary)
            }
            .link {
                ForegroundColor(.accentColor)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.875))
                BackgroundColor(Color.primary.opacity(0.07))
                ForegroundColor(.primary)
            }
            .codeBlock { cfg in
                CopyableCodeBlock(language: cfg.language, content: cfg.content)
            }
    }
}

// MARK: - Main document view

struct MarkdownDocumentView: View {
    let rawText: String
    let fontSize: CGFloat
    @Binding var scrollFraction: CGFloat
    var imageBaseURL: URL? = nil

    // Memoized: the document is parsed only when rawText changes, not on every body
    // re-evaluation. body re-runs on every scrollFraction update, and re-running the
    // whole-document regex parse each scroll tick was needless CPU on large files.
    @State private var segments: [DocSegment] = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    segmentView(seg)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            let maxOffset = geo.contentSize.height - geo.containerSize.height
            guard maxOffset > 0 else { return 0 }
            return geo.contentOffset.y / maxOffset
        } action: { _, new in
            scrollFraction = Swift.max(0, Swift.min(1, new))
        }
        .task(id: rawText) { segments = parseDocSegments(rawText) }
    }

    @ViewBuilder
    private func segmentView(_ seg: DocSegment) -> some View {
        switch seg {
        case .prose(let text):
            Markdown(text, imageBaseURL: imageBaseURL)
                .markdownTheme(.vera(fontSize: fontSize))
                .textSelection(.enabled)
                .padding(.vertical, 4)
        case .codeBlock(let lang, let code):
            CopyableCodeBlock(language: lang, content: code)
                .padding(.vertical, 6)
        case .table(let headers, let rows):
            DocTableBlock(headers: headers, rows: rows)
                .padding(.vertical, 6)
        }
    }
}

// MARK: - Plain-text / code preview (non-Markdown formats)

/// Read-mode preview for anything that isn't Markdown: no Markdown parsing, since stray
/// `#`/`*`/`|` characters in data or notes would otherwise be misread as syntax. A known
/// `language` gets monospaced Highlightr syntax highlighting (reusing `HighlightedCodeView`,
/// the same renderer fenced code blocks use); otherwise it wraps as regular body text.
struct PlainDocumentView: View {
    let rawText: String
    let fontSize: CGFloat
    let language: String?
    @Binding var scrollFraction: CGFloat

    var body: some View {
        ScrollView {
            Group {
                if let language {
                    HighlightedCodeView(code: rawText, language: language)
                } else {
                    Text(rawText)
                        .font(.system(size: fontSize))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            let maxOffset = geo.contentSize.height - geo.containerSize.height
            guard maxOffset > 0 else { return 0 }
            return geo.contentOffset.y / maxOffset
        } action: { _, new in
            scrollFraction = Swift.max(0, Swift.min(1, new))
        }
    }
}

// MARK: - Syntax-highlighted code view

struct HighlightedCodeView: View {
    let code: String
    let language: String?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(Defaults.Key.codeWrapEnabled) private var wrapEnabled = false
    @State private var highlighted: AttributedString?

    var body: some View {
        Group {
            if wrapEnabled {
                codeText
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    codeText
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 0, alignment: .leading)
                }
            }
        }
        .task(id: [code.hashValue, language.hashValue, colorScheme.hashValue, dynamicTypeSize.hashValue]) {
            highlighted = await computeHighlighted()
        }
    }

    @ViewBuilder
    private var codeText: some View {
        if let attr = highlighted {
            Text(attr)
                .textSelection(.enabled)
        } else {
            Text(code)
                .font(.system(size: Theme.Typography.codeSize * dynamicTypeSize.monoScale, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    private func computeHighlighted() async -> AttributedString? {
        guard let lang = language.flatMap({ FileKind.languageMap[$0.lowercased()] }) else { return nil }
        return await HighlightrEngine.shared.highlight(
            code: code,
            language: lang,
            theme: colorScheme == .dark ? "atom-one-dark" : "atom-one-light",
            fontSize: Theme.Typography.codeSize * dynamicTypeSize.monoScale
        )
    }
}

// MARK: - Copyable code block

struct CopyableCodeBlock: View {
    let language: String?
    let content: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                if let lang = language, !lang.isEmpty {
                    Text(lang)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button(action: doCopy) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "square.on.square")
                            .font(.system(size: 11))
                        Text(copied ? "Copied" : "Copy")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(copied ? 0.12 : 0.06)))
                    .foregroundStyle(copied ? Color.accentColor : Color.secondary)
                    .animation(.spring(duration: 0.2), value: copied)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider().opacity(0.5)

            HighlightedCodeView(code: content, language: language)
                .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func doCopy() {
        #if os(iOS)
        UIPasteboard.general.string = content
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        #endif
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { copied = false }
        }
    }
}

// MARK: - Table renderer

struct DocTableBlock: View {
    let headers: [String]
    let rows: [[String]]

    private var colWidths: [CGFloat] {
        let allRows = [headers] + rows.map { padded($0) }
        return (0..<headers.count).map { col in
            let maxLen = allRows.map { row in row[col].count }.max() ?? 1
            return CGFloat(maxLen) * 9.5 + 24.0
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { i, header in
                        cellView(text: header, isHeader: true,
                                 width: i < colWidths.count ? colWidths[i] : 100,
                                 isLast: i == headers.count - 1)
                    }
                }
                .background(Color.primary.opacity(0.07))
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { r, row in
                    HStack(spacing: 0) {
                        ForEach(Array(padded(row).enumerated()), id: \.offset) { i, cell in
                            cellView(text: cell, isHeader: false,
                                     width: i < colWidths.count ? colWidths[i] : 100,
                                     isLast: i == headers.count - 1)
                        }
                    }
                    .background(r % 2 == 1 ? Color.primary.opacity(0.03) : Color.clear)
                    Divider().opacity(0.4)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    @ViewBuilder
    private func cellView(text: String, isHeader: Bool, width: CGFloat, isLast: Bool) -> some View {
        Text(attrCell(text))
            .font(isHeader ? .footnote.weight(.semibold) : .footnote)
            .foregroundStyle(Color.primary)
            .lineLimit(2)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(width: width, alignment: .leading)
            .overlay(alignment: .trailing) {
                if !isLast {
                    Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 1)
                }
            }
    }

    private func padded(_ row: [String]) -> [String] {
        var r = row
        while r.count < headers.count { r.append("") }
        return Array(r.prefix(headers.count))
    }

    private func attrCell(_ cell: String) -> AttributedString {
        (try? AttributedString(
            markdown: cell,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(cell)
    }
}
