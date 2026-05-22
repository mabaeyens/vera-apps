import SwiftUI

// MARK: - iOS

#if os(iOS)
import UIKit

struct PreviewTextView: UIViewRepresentable {
    let rawText: String
    let fontSize: CGFloat
    @Binding var scrollFraction: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = true
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 16, bottom: 48, right: 16)
        tv.delegate = context.coordinator
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        let isDark = context.environment.colorScheme == .dark
        guard context.coordinator.needsUpdate(text: rawText, fontSize: fontSize, isDark: isDark) else { return }
        tv.attributedText = makeMarkdownAttributedString(rawText, fontSize: fontSize, isDarkMode: isDark)
        context.coordinator.record(text: rawText, fontSize: fontSize, isDark: isDark)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, UITextViewDelegate, UIScrollViewDelegate {
        var parent: PreviewTextView
        private var lastText = ""
        private var lastFontSize: CGFloat = 0
        private var lastIsDark = false

        init(_ parent: PreviewTextView) { self.parent = parent }

        func needsUpdate(text: String, fontSize: CGFloat, isDark: Bool) -> Bool {
            text != lastText || fontSize != lastFontSize || isDark != lastIsDark
        }

        func record(text: String, fontSize: CGFloat, isDark: Bool) {
            lastText = text; lastFontSize = fontSize; lastIsDark = isDark
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let scrollable = scrollView.contentSize.height - scrollView.bounds.height
            guard scrollable > 0 else { return }
            parent.scrollFraction = max(0, min(1, scrollView.contentOffset.y / scrollable))
        }
    }
}

// MARK: - macOS

#elseif os(macOS)
import AppKit

struct PreviewTextView: NSViewRepresentable {
    let rawText: String
    let fontSize: CGFloat
    @Binding var scrollFraction: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 20, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 32, right: 0)

        context.coordinator.scrollView = scrollView
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.boundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        let isDark = context.environment.colorScheme == .dark
        guard context.coordinator.needsUpdate(text: rawText, fontSize: fontSize, isDark: isDark) else { return }
        let attr = makeMarkdownAttributedString(rawText, fontSize: fontSize, isDarkMode: isDark)
        textView.textStorage?.setAttributedString(attr)
        context.coordinator.record(text: rawText, fontSize: fontSize, isDark: isDark)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject {
        var parent: PreviewTextView
        weak var scrollView: NSScrollView?
        private var lastText = ""
        private var lastFontSize: CGFloat = 0
        private var lastIsDark = false

        init(_ parent: PreviewTextView) { self.parent = parent }

        deinit { NotificationCenter.default.removeObserver(self) }

        func needsUpdate(text: String, fontSize: CGFloat, isDark: Bool) -> Bool {
            text != lastText || fontSize != lastFontSize || isDark != lastIsDark
        }

        func record(text: String, fontSize: CGFloat, isDark: Bool) {
            lastText = text; lastFontSize = fontSize; lastIsDark = isDark
        }

        @objc func boundsDidChange(_ notification: Notification) {
            guard let sv = scrollView,
                  let docView = sv.documentView else { return }
            let contentHeight = docView.frame.height
            let viewHeight    = sv.contentView.bounds.height
            let scrollable    = contentHeight - viewHeight
            guard scrollable > 0 else { return }
            let offset = sv.contentView.bounds.origin.y
            parent.scrollFraction = max(0, min(1, offset / scrollable))
        }
    }
}
#endif
