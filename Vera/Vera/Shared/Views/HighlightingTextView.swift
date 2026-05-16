import SwiftUI
import Highlightr

// MARK: - iOS

#if os(iOS)
import UIKit

struct HighlightingTextView: UIViewRepresentable {
    @Binding var text: String
    let onTextChange: () -> Void
    let registerInsert: (@escaping (String) -> Void) -> Void
    let registerWrap: (@escaping (String, String) -> Void) -> Void
    let registerStrip: (@escaping () -> Void) -> Void
    let onShowAtlas: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let textStorage = CodeAttributedString()
        textStorage.language = "markdown"

        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: .zero)
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        // Set theme font before creating the text view; Highlightr's theme overrides textView.font
        textStorage.highlightr.setTheme(to: "atom-one-light")
        textStorage.highlightr.theme?.setCodeFont(UIFont.monospacedSystemFont(ofSize: 20, weight: .regular))

        let textView = UITextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.text = text
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        context.coordinator.textView = textView

        registerInsert { [weak coordinator = context.coordinator] snippet in
            coordinator?.insert(snippet)
        }
        registerWrap { [weak coordinator = context.coordinator] prefix, suffix in
            coordinator?.wrap(prefix: prefix, suffix: suffix)
        }
        registerStrip { [weak coordinator = context.coordinator] in
            coordinator?.strip()
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            let sel = uiView.selectedRange
            uiView.text = text
            uiView.selectedRange = sel
        }
        if let storage = uiView.textStorage as? CodeAttributedString {
            let theme = context.environment.colorScheme == .dark ? "atom-one-dark" : "atom-one-light"
            storage.highlightr.setTheme(to: theme)
            storage.highlightr.theme?.setCodeFont(UIFont.monospacedSystemFont(ofSize: 20, weight: .regular))
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: HighlightingTextView
        weak var textView: UITextView?
        private var lastKnownRange: UITextRange?

        init(_ parent: HighlightingTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onTextChange()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            lastKnownRange = textView.selectedTextRange
        }

        // MARK: Context menu (iOS 16+)

        func textView(
            _ textView: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            var extras: [UIMenuElement] = []

            let formatAction = UIAction(
                title: "Format…",
                image: UIImage(systemName: "wand.and.stars")
            ) { [weak self] _ in
                self?.parent.onShowAtlas()
            }
            extras.append(formatAction)

            if range.length > 0 {
                let stripAction = UIAction(
                    title: "Remove Formatting",
                    image: UIImage(systemName: "eraser")
                ) { [weak self] _ in
                    self?.strip()
                }
                extras.append(stripAction)
            }

            return UIMenu(children: suggestedActions + extras)
        }

        // MARK: Mutations

        func insert(_ snippet: String) {
            guard let tv = textView else { return }
            let range: UITextRange
            if let r = lastKnownRange {
                range = r
            } else if let r = tv.selectedTextRange {
                range = r
            } else {
                let end = tv.endOfDocument
                guard let r = tv.textRange(from: end, to: end) else { return }
                range = r
            }
            tv.replace(range, withText: snippet)
            parent.text = tv.text
            parent.onTextChange()
        }

        func wrap(prefix: String, suffix: String) {
            guard let tv = textView else { return }
            let range: UITextRange
            if let r = lastKnownRange {
                range = r
            } else if let r = tv.selectedTextRange {
                range = r
            } else {
                let end = tv.endOfDocument
                guard let r = tv.textRange(from: end, to: end) else { return }
                range = r
            }
            let selected = tv.text(in: range) ?? ""
            tv.replace(range, withText: prefix + selected + suffix)
            parent.text = tv.text
            parent.onTextChange()
        }

        func strip() {
            guard let tv = textView else { return }
            let range: UITextRange
            if let r = lastKnownRange {
                range = r
            } else if let r = tv.selectedTextRange {
                range = r
            } else { return }
            let selected = tv.text(in: range) ?? ""
            guard !selected.isEmpty else { return }
            tv.replace(range, withText: selected.strippingMarkdown())
            parent.text = tv.text
            parent.onTextChange()
        }
    }
}

// MARK: - macOS

#elseif os(macOS)
import AppKit

struct HighlightingTextView: NSViewRepresentable {
    @Binding var text: String
    let onTextChange: () -> Void
    let registerInsert: (@escaping (String) -> Void) -> Void
    let registerWrap: (@escaping (String, String) -> Void) -> Void
    let registerStrip: (@escaping () -> Void) -> Void
    let onShowAtlas: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textStorage = CodeAttributedString()
        textStorage.language = "markdown"

        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(
            containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        textStorage.highlightr.setTheme(to: "atom-one-light")
        textStorage.highlightr.theme?.setCodeFont(NSFont.monospacedSystemFont(ofSize: 17, weight: .regular))

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 20, height: 12)
        textView.string = text
        context.coordinator.textView = textView

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 44, right: 0)

        registerInsert { [weak coordinator = context.coordinator] snippet in
            coordinator?.insert(snippet)
        }
        registerWrap { [weak coordinator = context.coordinator] prefix, suffix in
            coordinator?.wrap(prefix: prefix, suffix: suffix)
        }
        registerStrip { [weak coordinator = context.coordinator] in
            coordinator?.strip()
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            let sel = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = sel
        }
        if let storage = textView.textStorage as? CodeAttributedString {
            let theme = context.environment.colorScheme == .dark ? "atom-one-dark" : "atom-one-light"
            storage.highlightr.setTheme(to: theme)
            storage.highlightr.theme?.setCodeFont(NSFont.monospacedSystemFont(ofSize: 17, weight: .regular))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: HighlightingTextView
        weak var textView: NSTextView?
        private var lastKnownRange: NSRange?

        init(_ parent: HighlightingTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            parent.onTextChange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            lastKnownRange = textView?.selectedRange()
        }

        // MARK: Context menu (macOS)

        func textView(
            _ view: NSTextView,
            menu: NSMenu,
            for event: NSEvent,
            at charIndex: Int
        ) -> NSMenu? {
            menu.addItem(.separator())

            let formatItem = NSMenuItem(title: "Format…", action: #selector(showAtlasAction), keyEquivalent: "")
            formatItem.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil)
            formatItem.target = self
            menu.addItem(formatItem)

            if view.selectedRange().length > 0 {
                let stripItem = NSMenuItem(title: "Remove Formatting", action: #selector(stripAction), keyEquivalent: "")
                stripItem.image = NSImage(systemSymbolName: "eraser", accessibilityDescription: nil)
                stripItem.target = self
                menu.addItem(stripItem)
            }

            return menu
        }

        @objc private func showAtlasAction() { parent.onShowAtlas() }
        @objc private func stripAction() { strip() }

        // MARK: Mutations

        func insert(_ snippet: String) {
            guard let tv = textView else { return }
            let range = lastKnownRange ?? tv.selectedRange()
            tv.insertText(snippet, replacementRange: range)
            parent.text = tv.string
            parent.onTextChange()
        }

        func wrap(prefix: String, suffix: String) {
            guard let tv = textView else { return }
            let range = lastKnownRange ?? tv.selectedRange()
            let selected = (tv.string as NSString).substring(with: range)
            tv.insertText(prefix + selected + suffix, replacementRange: range)
            parent.text = tv.string
            parent.onTextChange()
        }

        func strip() {
            guard let tv = textView else { return }
            let range = lastKnownRange ?? tv.selectedRange()
            guard range.length > 0 else { return }
            let selected = (tv.string as NSString).substring(with: range)
            tv.insertText(selected.strippingMarkdown(), replacementRange: range)
            parent.text = tv.string
            parent.onTextChange()
        }
    }
}
#endif
