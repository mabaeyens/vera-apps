#if os(macOS)
import SwiftUI

/// The macOS Settings window (⌘,).
///
/// Vera had no `Settings` scene at all, so there was no ⌘, and the only preference in the
/// app — the Markdown linter toggle — was buried inside the About sheet, which is not
/// where anyone looks for settings. About keeps its copy so existing muscle memory still
/// works; both read the same `Defaults` keys, so they can't disagree.
struct SettingsView: View {
    @AppStorage(Defaults.Key.editorFontSize) private var fontSize = Defaults.FontSize.default
    @AppStorage(Defaults.Key.linterEnabled) private var linterEnabled = true
    @AppStorage(Defaults.Key.lineNumbersEnabled) private var lineNumbers = true
    @AppStorage(Defaults.Key.codeWrapEnabled) private var wrapCode = false

    var body: some View {
        Form {
            Section("Editor") {
                LabeledContent("Text Size") {
                    HStack(spacing: Theme.Space.m) {
                        Slider(
                            value: $fontSize,
                            in: Defaults.FontSize.min...Defaults.FontSize.max,
                            step: Defaults.FontSize.step
                        )
                        .frame(width: 180)
                        Text("\(Int(fontSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Button("Reset") { fontSize = Double(Theme.Typography.codeSize) }
                            .disabled(fontSize == Double(Theme.Typography.codeSize))
                    }
                }
                Toggle("Show Line Numbers", isOn: $lineNumbers)
                Toggle("Wrap Long Lines", isOn: $wrapCode)
            }

            Section("Markdown") {
                Toggle("Markdown Linter", isOn: $linterEnabled)
                Text("Flags common Markdown problems while you write.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
#endif
