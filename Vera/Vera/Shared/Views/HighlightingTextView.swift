import SwiftUI
import Highlightr

// MARK: - iOS

#if os(iOS)
import UIKit

struct HighlightingTextView: UIViewRepresentable {
    @Binding var text: String
    let onTextChange: () -> Void
    let registerInsert: (@escaping (String) -> Void) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let textStorage = CodeAttributedString()
        textStorage.language = "markdown"

        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: .zero)
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = UITextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.font = UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular)
        textView.backgroundColor = .clear
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.text = text
        context.coordinator.textView = textView

        registerInsert { [weak coordinator = context.coordinator] snippet in
            coordinator?.insert(snippet)
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
    }
}

// MARK: - macOS

#elseif os(macOS)
import AppKit

struct HighlightingTextView: NSViewRepresentable {
    @Binding var text: String
    let onTextChange: () -> Void
    let registerInsert: (@escaping (String) -> Void) -> Void

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

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = text
        context.coordinator.textView = textView

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        registerInsert { [weak coordinator = context.coordinator] snippet in
            coordinator?.insert(snippet)
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

        func insert(_ snippet: String) {
            guard let tv = textView else { return }
            let range = lastKnownRange ?? tv.selectedRange()
            tv.insertText(snippet, replacementRange: range)
            parent.text = tv.string
            parent.onTextChange()
        }
    }
}
#endif
