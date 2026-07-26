import SwiftUI
import MarkdownUI

// MARK: - Document segment model

private enum DocSegment: Sendable {
    case prose(String)
    case codeBlock(language: String?, content: String)
    case table(headers: [String], rows: [[String]])
}

private nonisolated func parseDocSegments(_ raw: String) -> [DocSegment] {
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

private nonisolated func splitDocTables(_ text: String) -> [DocSegment] {
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

private nonisolated func isDocTableRow(_ line: String) -> Bool {
    line.trimmingCharacters(in: .whitespaces).contains("|")
}

private nonisolated func isDocTableSeparator(_ line: String) -> Bool {
    let t = line.trimmingCharacters(in: .whitespaces)
    guard t.contains("|"), t.contains("-") else { return false }
    let stripped = t
        .replacingOccurrences(of: "|", with: "")
        .replacingOccurrences(of: "-", with: "")
        .replacingOccurrences(of: ":", with: "")
        .replacingOccurrences(of: " ", with: "")
    return stripped.isEmpty
}

private nonisolated func docTableRowCells(_ line: String) -> [String] {
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
                CopyableCodeBlock(language: cfg.language, content: cfg.content, fontSize: fontSize)
            }
    }
}

// MARK: - Main document view

struct MarkdownDocumentView: View {
    let rawText: String
    let fontSize: CGFloat
    // A plain write-only closure, not a `@Binding` into the view model: binding through
    // `$viewModel.someProperty` reads the property to build the binding, which makes the
    // *owning* view's body a tracked dependent of it — so every scroll-geometry tick would
    // re-invoke that ancestor's body, reconstruct this ScrollView, and re-trigger geometry
    // evaluation within the same frame. That feedback loop is what SwiftUI's "OnScrollGeometryChange
    // Modifier tried to update multiple times per frame" fault reports, and it pegged CPU on iPad.
    // A closure writes without reading, so the ancestor never subscribes to the value.
    var onScrollFractionChange: (CGFloat) -> Void = { _ in }
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
            onScrollFractionChange(Swift.max(0, Swift.min(1, new)))
        }
        // `parseDocSegments` runs a whole-document regex plus a line-by-line table scan.
        // It has no `await`, so inside a plain `.task` it inherited this view's MainActor
        // isolation and ran the entire pass on the main thread at every file open. The
        // detached task moves it off; the result is a plain value type coming back.
        .task(id: rawText) {
            let text = rawText
            let parsed = await Task.detached(priority: .userInitiated) {
                parseDocSegments(text)
            }.value
            guard !Task.isCancelled else { return }
            segments = parsed
        }
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
            CopyableCodeBlock(language: lang, content: code, fontSize: fontSize)
                .padding(.vertical, 6)
        case .table(let headers, let rows):
            DocTableBlock(headers: headers, rows: rows, fontSize: fontSize)
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
    // See the matching comment on `MarkdownDocumentView.onScrollFractionChange` — a plain
    // write-only closure, not a `@Binding`, so the owning view never becomes a tracked
    // dependent of the scroll fraction and can't re-trigger geometry evaluation mid-frame.
    var onScrollFractionChange: (CGFloat) -> Void = { _ in }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            Group {
                if let language {
                    HighlightedCodeView(code: rawText, language: language, baseFontSize: fontSize)
                } else {
                    Text(rawText)
                        // Raw `.font(.system(size:))` gets no Dynamic Type for free, so
                        // this was the one surface that ignored Larger Text entirely.
                        .font(.system(size: Theme.Typography.size(
                            .body, preference: fontSize, typeSize: dynamicTypeSize
                        )))
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
            onScrollFractionChange(Swift.max(0, Swift.min(1, new)))
        }
    }
}

// MARK: - Syntax-highlighted code view

struct HighlightedCodeView: View {
    let code: String
    let language: String?
    var baseFontSize: CGFloat = Theme.Typography.codeSize

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(Defaults.Key.codeWrapEnabled) private var wrapEnabled = false
    @State private var highlightedLines: [AttributedString]?

    // A single very long line (e.g. one minified line in a bundled asset) can produce
    // an intrinsic Text width past practical CALayer backing-store limits, which draws
    // blank. Force-wrap just that one line regardless of the wrap toggle, rather than
    // letting one pathological line blank out — every other line stays unaffected since
    // each is now its own row/Text, not one Text for the whole file.
    private static let maxUnwrappedLineLength = 2000

    // The user's font-size preference (the A/A toolbar buttons) resolved through the one
    // shared type scale, so a code block reads at exactly the size the editor uses for the
    // same text. This used to apply Vera's own `monoScale` while the surrounding prose
    // used Apple's ramp inside MarkdownUI, which is why code blocks and body text drifted
    // apart as Dynamic Type grew.
    private var fontSize: CGFloat {
        Theme.Typography.size(.code, preference: baseFontSize, typeSize: dynamicTypeSize)
    }

    /// Identity for the highlight task. Deliberately holds `code` itself rather than
    /// `code.hashValue`: hashing always walks the whole document, and this id is compared
    /// on every view update, whereas comparing a String against itself hits the
    /// identical-storage fast path. `fontSize` already folds in Dynamic Type, so
    /// `dynamicTypeSize` doesn't need to appear here.
    private struct HighlightKey: Equatable {
        let code: String
        let language: String?
        let isDark: Bool
        let fontSize: CGFloat
    }

    /// Past this the engine returns plain text rather than risking an uninterruptible
    /// highlight pass. Say so instead of leaving the user wondering where the colour went.
    private var isTooLargeToHighlight: Bool {
        language != nil && code.utf8.count > HighlightrEngine.maxHighlightBytes
    }

    var body: some View {
        // One pass produces both the lines and the widest line, instead of a split
        // followed by separate map/filter/max passes. This runs per body evaluation, and
        // body re-evaluates on scroll (the parent writes scroll geometry into the view
        // model), so it is genuinely hot.
        let split = Self.splitCode(code)
        Group {
            VStack(alignment: .leading, spacing: 0) {
                if isTooLargeToHighlight {
                    Label(
                        "Syntax highlighting is off for this file — it's over \(HighlightrEngine.maxHighlightBytes / 1_000_000) MB.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Theme.Space.m)
                    .padding(.vertical, Theme.Space.s)
                }
                if wrapEnabled {
                    lineRows(split)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        lineRows(split)
                    }
                }
            }
        }
        .task(id: HighlightKey(
            code: code,
            language: language,
            isDark: colorScheme == .dark,
            fontSize: fontSize
        )) {
            highlightedLines = await computeHighlightedLines()
        }
    }

    /// Lines plus the longest non-pathological line length, in a single traversal.
    private static func splitCode(_ code: String) -> (lines: [Substring], maxChars: Int) {
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
        var maxChars = 0
        for line in lines {
            let count = line.count
            if count <= maxUnwrappedLineLength && count > maxChars { maxChars = count }
        }
        return (lines, maxChars)
    }

    private func lineRows(_ split: (lines: [Substring], maxChars: Int)) -> some View {
        let lines = split.lines
        let gutterDigits = max(2, String(lines.count).count)
        let gutterWidth = CGFloat(gutterDigits) * fontSize * 0.62 + 6
        // SF Mono is fixed-width, so one upfront max-length pass gives an exact row width
        // for every line, computed once. This replaces a per-row `.fixedSize` intrinsic-size
        // measurement, which forced UIKit to resolve N independent lazy layout passes any
        // time fontSize changed — traced as the likely cause of an iPad-only layout
        // non-convergence hang inside the horizontal ScrollView (see IPAD_FONT_SIZE_HANG.md).
        // Excludes pathological long lines (forced to wrap below) so one minified line can't
        // blow up the shared width for every other row.
        let maxLineWidth = CGFloat(split.maxChars) * fontSize * 0.62
        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, plainLine in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1)")
                        .font(.system(size: fontSize, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .frame(minWidth: gutterWidth, alignment: .trailing)
                    lineText(index: index, plainLine: plainLine)
                        .textSelection(.enabled)
                        .modifier(LineWidthModifier(
                            wrap: wrapEnabled || plainLine.count > Self.maxUnwrappedLineLength,
                            fixedWidth: maxLineWidth
                        ))
                }
            }
        }
    }

    private func lineText(index: Int, plainLine: Substring) -> Text {
        if let highlightedLines, index < highlightedLines.count {
            return Text(highlightedLines[index])
        }
        return Text(String(plainLine))
            .font(.system(size: fontSize, design: .monospaced))
            .foregroundStyle(.primary)
    }

    private func computeHighlightedLines() async -> [AttributedString]? {
        guard let lang = language.flatMap({ FileKind.languageMap[$0.lowercased()] }) else { return nil }
        // Splitting happens inside the actor now — awaiting `highlight` and splitting here
        // resumed on the MainActor, putting a full-document character walk with one
        // allocation per line back on the main thread right after taking it off.
        return await HighlightrEngine.shared.highlightLines(
            code: code,
            language: lang,
            theme: colorScheme == .dark ? "atom-one-dark" : "atom-one-light",
            fontSize: fontSize
        )
    }
}

/// Applies either a flexible (wrap) or a fixed-intrinsic-size (horizontal-scroll) width
/// to a single line's `Text`, per-row rather than for the whole document — the fix for
/// item 8's blank-render bug hinges on no single `Text` ever spanning more than one line.
private struct LineWidthModifier: ViewModifier {
    let wrap: Bool
    let fixedWidth: CGFloat
    func body(content: Content) -> some View {
        if wrap {
            content.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            content.frame(width: fixedWidth, alignment: .leading)
        }
    }
}

// MARK: - Copyable code block

struct CopyableCodeBlock: View {
    let language: String?
    let content: String
    var fontSize: CGFloat = Theme.Typography.codeSize
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

            HighlightedCodeView(code: content, language: language, baseFontSize: fontSize)
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
    var fontSize: CGFloat = CGFloat(Defaults.FontSize.default)

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Table cells read at the same size as the prose around them. They used to carry a
    // hardcoded `* 0.8`, left over from emulating a `.footnote` text style, *and* no
    // Dynamic Type at all — so tables were the smallest text on screen at every
    // accessibility size, pinned at 14.4pt while the editor reached ~55.8pt.
    private var cellFontSize: CGFloat {
        Theme.Typography.size(.table, preference: fontSize, typeSize: dynamicTypeSize)
    }

    /// Longest cell per column, in characters. The expensive part is scanning every cell,
    /// and that is font-independent, so it happens once in `init` rather than per body
    /// evaluation — `colWidths` below then only walks the columns. (It used to be a
    /// computed property scanning the whole table, read twice per row render.)
    private let colMaxChars: [Int]

    private var colWidths: [CGFloat] {
        // Per-character width heuristic, scaled proportionally to cellFontSize so columns
        // stay wide enough to fit the text (not just the text itself) as font size changes.
        let charWidth = cellFontSize * 0.73
        return colMaxChars.map { CGFloat($0) * charWidth + 24.0 }
    }

    init(headers: [String], rows: [[String]], fontSize: CGFloat = CGFloat(Defaults.FontSize.default)) {
        self.headers = headers
        self.rows = rows
        self.fontSize = fontSize

        let allRows = [headers] + rows.map { Self.padded($0, to: headers.count) }
        self.colMaxChars = (0..<headers.count).map { col in
            allRows.map { row in row[col].count }.max() ?? 1
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
            .font(isHeader ? .system(size: cellFontSize).weight(.semibold) : .system(size: cellFontSize))
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
        Self.padded(row, to: headers.count)
    }

    /// Static so `init` can use it while computing `colWidths`, before `self` is whole.
    private static func padded(_ row: [String], to count: Int) -> [String] {
        var r = row
        while r.count < count { r.append("") }
        return Array(r.prefix(count))
    }

    private func attrCell(_ cell: String) -> AttributedString {
        (try? AttributedString(
            markdown: cell,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(cell)
    }
}
