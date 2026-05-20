import SwiftUI
import Highlightr

// MARK: - iOS

#if os(iOS)
import UIKit

struct HighlightingTextView: UIViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    let onTextChange: () -> Void
    let registerInsert: (@escaping (String) -> Void) -> Void
    let registerWrap: (@escaping (String, String) -> Void) -> Void
    let registerStrip: (@escaping () -> Void) -> Void
    var scrollFraction: CGFloat?
    var clearAnchor: () -> Void
    var onAtlasRequested: () -> Void = {}
    var onCheatSheetRequested: () -> Void = {}
    var onIconHelpRequested: () -> Void = {}
    var useInputAccessory: Bool = true
    var onEditingChanged: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let textStorage = CodeAttributedString()
        textStorage.language = "markdown"

        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: .zero)
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        textStorage.highlightr.setTheme(to: "atom-one-light")
        textStorage.highlightr.theme?.setCodeFont(UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular))

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

        // Store callbacks before building the bar so the more menu closure captures them
        context.coordinator.onAtlasRequested = onAtlasRequested
        context.coordinator.onCheatSheetRequested = onCheatSheetRequested
        context.coordinator.onIconHelpRequested = onIconHelpRequested

        if useInputAccessory {
            textView.inputAccessoryView = makeFormattingBar(coordinator: context.coordinator)
        }

        registerInsert { [weak coordinator = context.coordinator] snippet in
            coordinator?.insert(snippet)
        }
        registerWrap { [weak coordinator = context.coordinator] prefix, suffix in
            coordinator?.wrap(prefix: prefix, suffix: suffix)
        }
        registerStrip { [weak coordinator = context.coordinator] in
            coordinator?.strip()
        }

        // Scroll to anchor position when entering edit mode from preview
        if let fraction = scrollFraction {
            let clear = clearAnchor
            DispatchQueue.main.async { [weak textView] in
                guard let tv = textView else { return }
                let total = tv.text.count
                if total > 0 {
                    let target = Int(Double(total) * fraction)
                    let clamped = max(0, min(target, total - 1))
                    tv.scrollRangeToVisible(NSRange(location: clamped, length: 0))
                }
                clear()
            }
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Refresh callbacks so the more-menu closure always calls the current SwiftUI handlers
        context.coordinator.onAtlasRequested = onAtlasRequested
        context.coordinator.onCheatSheetRequested = onCheatSheetRequested
        context.coordinator.onIconHelpRequested = onIconHelpRequested
        context.coordinator.refreshMoreMenu()

        if uiView.text != text {
            let sel = uiView.selectedRange
            context.coordinator.isApplyingExternalChange = true
            if let range = uiView.textRange(from: uiView.beginningOfDocument, to: uiView.endOfDocument) {
                uiView.replace(range, withText: text)
            }
            context.coordinator.isApplyingExternalChange = false
            uiView.selectedRange = sel
        }
        let newTheme = context.environment.colorScheme == .dark ? "atom-one-dark" : "atom-one-light"
        if fontSize != context.coordinator.lastFontSize || newTheme != context.coordinator.lastTheme {
            if let storage = uiView.textStorage as? CodeAttributedString {
                storage.highlightr.setTheme(to: newTheme)
                storage.highlightr.theme?.setCodeFont(UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular))
                if storage.length > 0 {
                    let fullRange = NSRange(location: 0, length: storage.length)
                    storage.beginEditing()
                    storage.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular), range: fullRange)
                    storage.endEditing()
                }
                storage.language = nil
                storage.language = "markdown"
            }
            context.coordinator.lastFontSize = fontSize
            context.coordinator.lastTheme = newTheme
        }
    }

    // MARK: - Formatting bar

    private func makeFormattingBar(coordinator: Coordinator) -> UIView {
        // UIInputView with .keyboard style blends seamlessly with the keyboard background
        let container = UIInputView(
            frame: CGRect(x: 0, y: 0, width: 0, height: 44),
            inputViewStyle: .keyboard
        )
        container.autoresizingMask = [.flexibleWidth]

        // More button (UIMenu — grouped sections replace the scrollable overflow)
        let moreBtn = UIButton(type: .system)
        moreBtn.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        moreBtn.tintColor = .label
        moreBtn.showsMenuAsPrimaryAction = true
        coordinator.moreButton = moreBtn
        coordinator.refreshMoreMenu()

        func iconButton(_ sfName: String, action: Selector) -> UIButton {
            let b = UIButton(type: .system)
            b.setImage(UIImage(systemName: sfName), for: .normal)
            b.tintColor = .label
            b.addTarget(coordinator, action: action, for: .primaryActionTriggered)
            return b
        }

        let stack = UIStackView(arrangedSubviews: [
            iconButton("wand.and.stars", action: #selector(Coordinator.triggerAtlas)),
            moreBtn
        ])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: HighlightingTextView
        weak var textView: UITextView?
        private var lastKnownRange: UITextRange?

        var lastFontSize: CGFloat = 0
        var lastTheme: String = ""
        var isApplyingExternalChange = false

        var onAtlasRequested: () -> Void = {}
        var onCheatSheetRequested: () -> Void = {}
        var onIconHelpRequested: () -> Void = {}
        weak var moreButton: UIButton?

        init(_ parent: HighlightingTextView) { self.parent = parent }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onEditingChanged(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onEditingChanged(false)
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingExternalChange else { return }
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
            if range.length > 0 {
                let stripAction = UIAction(
                    title: "Remove Formatting",
                    image: UIImage(systemName: "eraser")
                ) { [weak self] _ in self?.strip() }
                extras.append(stripAction)
            }
            return UIMenu(children: extras + suggestedActions)
        }

        // MARK: Formatting bar actions

        @objc func performUndo() { textView?.undoManager?.undo() }
        @objc func performRedo() { textView?.undoManager?.redo() }
        @objc func applyBold()    { wrap(prefix: "**", suffix: "**") }
        @objc func applyItalic()  { wrap(prefix: "_", suffix: "_") }
        @objc func applyStrike()  { wrap(prefix: "~~", suffix: "~~") }
        @objc func applyCode()    { wrap(prefix: "`", suffix: "`") }
        @objc func applyHeading() { insert("## ") }
        @objc func applyList()    { insert("- ") }
        @objc func applyQuote()   { insert("> ") }
        @objc func triggerAtlas() { onAtlasRequested() }

        func refreshMoreMenu() {
            let cheatSheet = onCheatSheetRequested
            let iconHelp = onIconHelpRequested

            let historyGroup = UIMenu(options: .displayInline, children: [
                UIAction(title: "Undo", image: UIImage(systemName: "arrow.uturn.backward")) { [weak self] _ in self?.performUndo() },
                UIAction(title: "Redo", image: UIImage(systemName: "arrow.uturn.forward")) { [weak self] _ in self?.performRedo() }
            ])
            let formatGroup = UIMenu(options: .displayInline, children: [
                UIAction(title: "Strikethrough", image: UIImage(systemName: "strikethrough")) { [weak self] _ in self?.applyStrike() },
                UIAction(title: "Code", image: UIImage(systemName: "chevron.left.forwardslash.chevron.right")) { [weak self] _ in self?.applyCode() },
                UIAction(title: "List", image: UIImage(systemName: "list.bullet")) { [weak self] _ in self?.applyList() },
                UIAction(title: "Quote", image: UIImage(systemName: "text.quote")) { [weak self] _ in self?.applyQuote() }
            ])
            let settingsGroup = UIMenu(options: .displayInline, children: [
                UIAction(title: "Larger Text", image: UIImage(systemName: "textformat.size.larger")) { _ in
                    let v = UserDefaults.standard.double(forKey: "editorFontSize").nonZero(default: 20)
                    UserDefaults.standard.set(min(32.0, v + 1), forKey: "editorFontSize")
                },
                UIAction(title: "Smaller Text", image: UIImage(systemName: "textformat.size.smaller")) { _ in
                    let v = UserDefaults.standard.double(forKey: "editorFontSize").nonZero(default: 20)
                    UserDefaults.standard.set(max(12.0, v - 1), forKey: "editorFontSize")
                },
                UIAction(title: "Markdown Reference", image: UIImage(systemName: "book.closed")) { _ in cheatSheet() },
                UIAction(title: "Icon Help", image: UIImage(systemName: "questionmark.circle")) { _ in iconHelp() }
            ])
            moreButton?.menu = UIMenu(children: [historyGroup, formatGroup, settingsGroup])
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

private extension Double {
    func nonZero(default fallback: Double) -> Double { self == 0 ? fallback : self }
}

// MARK: - macOS

#elseif os(macOS)
import AppKit

private final class FormattingTextView: NSTextView {
    weak var coordinator: HighlightingTextView.Coordinator?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) else { return super.performKeyEquivalent(with: event) }
        let shift = flags.contains(.shift)
        switch (event.charactersIgnoringModifiers ?? "", shift) {
        case ("b", false): coordinator?.applyBold();   return true
        case ("i", false): coordinator?.applyItalic(); return true
        case ("x", true):  coordinator?.applyStrike(); return true
        case ("c", true):  coordinator?.applyCode();   return true
        default:           return super.performKeyEquivalent(with: event)
        }
    }
}

struct HighlightingTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    let onTextChange: () -> Void
    let registerInsert: (@escaping (String) -> Void) -> Void
    let registerWrap: (@escaping (String, String) -> Void) -> Void
    let registerStrip: (@escaping () -> Void) -> Void
    var scrollFraction: CGFloat?
    var clearAnchor: () -> Void
    var onAtlasRequested: () -> Void = {}
    var onCheatSheetRequested: () -> Void = {}
    var onIconHelpRequested: () -> Void = {}
    var useInputAccessory: Bool = true   // unused on macOS, kept for shared call site
    var onEditingChanged: (Bool) -> Void = { _ in }  // unused on macOS

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
        textStorage.highlightr.theme?.setCodeFont(NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular))

        let textView = FormattingTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.allowsUndo = true
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
        textView.coordinator = context.coordinator

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

        // Scroll to anchor position when entering edit mode from preview
        if let fraction = scrollFraction {
            let clear = clearAnchor
            DispatchQueue.main.async { [weak textView] in
                guard let tv = textView else { return }
                let total = tv.string.count
                if total > 0 {
                    let target = Int(Double(total) * fraction)
                    let clamped = max(0, min(target, total - 1))
                    tv.scrollRangeToVisible(NSRange(location: clamped, length: 0))
                }
                clear()
            }
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            let sel = textView.selectedRanges
            // Go through textStorage directly instead of insertText: this updates the
            // text without touching the undo manager at all (no new entry, no stack clear).
            if let storage = textView.textStorage {
                storage.beginEditing()
                storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
                storage.endEditing()
            }
            textView.selectedRanges = sel
        }
        let newTheme = context.environment.colorScheme == .dark ? "atom-one-dark" : "atom-one-light"
        if fontSize != context.coordinator.lastFontSize || newTheme != context.coordinator.lastTheme {
            if let storage = textView.textStorage as? CodeAttributedString {
                storage.highlightr.setTheme(to: newTheme)
                storage.highlightr.theme?.setCodeFont(NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular))
                if storage.length > 0 {
                    let fullRange = NSRange(location: 0, length: storage.length)
                    storage.beginEditing()
                    storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular), range: fullRange)
                    storage.endEditing()
                }
                storage.language = nil
                storage.language = "markdown"
            }
            context.coordinator.lastFontSize = fontSize
            context.coordinator.lastTheme = newTheme
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: HighlightingTextView
        weak var textView: NSTextView?
        private var lastKnownRange: NSRange?

        var lastFontSize: CGFloat = 0
        var lastTheme: String = ""

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
            let formatMenu = NSMenu(title: "Format")

            func item(_ title: String, sel: Selector, key: String = "", shift: Bool = false) -> NSMenuItem {
                let it = NSMenuItem(title: title, action: sel, keyEquivalent: key)
                it.target = self
                if shift { it.keyEquivalentModifierMask = [.command, .shift] }
                return it
            }

            formatMenu.addItem(item("Bold",          sel: #selector(applyBold),   key: "b"))
            formatMenu.addItem(item("Italic",        sel: #selector(applyItalic), key: "i"))
            formatMenu.addItem(item("Strikethrough", sel: #selector(applyStrike), key: "x", shift: true))
            formatMenu.addItem(item("Code",          sel: #selector(applyCode),   key: "c", shift: true))
            formatMenu.addItem(.separator())
            formatMenu.addItem(item("Heading",       sel: #selector(applyHeading)))
            formatMenu.addItem(item("List Item",     sel: #selector(applyList)))
            formatMenu.addItem(item("Quote",         sel: #selector(applyQuote)))
            formatMenu.addItem(.separator())
            formatMenu.addItem(item("Markdown Reference…", sel: #selector(openCheatSheet)))
            formatMenu.addItem(item("Icon Help…",          sel: #selector(openIconHelp)))

            let formatItem = NSMenuItem(title: "Format", action: nil, keyEquivalent: "")
            formatItem.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil)
            formatItem.submenu = formatMenu
            menu.insertItem(formatItem, at: 0)
            menu.insertItem(.separator(), at: 1)

            if view.selectedRange().length > 0 {
                let stripItem = NSMenuItem(title: "Remove Formatting", action: #selector(stripAction), keyEquivalent: "")
                stripItem.image = NSImage(systemSymbolName: "eraser", accessibilityDescription: nil)
                stripItem.target = self
                menu.insertItem(stripItem, at: 2)
                menu.insertItem(.separator(), at: 3)
            }
            return menu
        }

        @objc private func stripAction()    { strip() }
        @objc func applyBold()              { wrap(prefix: "**", suffix: "**") }
        @objc func applyItalic()            { wrap(prefix: "_", suffix: "_") }
        @objc func applyStrike()            { wrap(prefix: "~~", suffix: "~~") }
        @objc func applyCode()              { wrap(prefix: "`", suffix: "`") }
        @objc private func applyHeading()   { insert("## ") }
        @objc private func applyList()      { insert("- ") }
        @objc private func applyQuote()     { insert("> ") }
        @objc private func openCheatSheet() { parent.onCheatSheetRequested() }
        @objc private func openIconHelp()   { parent.onIconHelpRequested() }

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
