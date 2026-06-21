import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var onReset: (() -> Void)? = nil

    @AppStorage("linterEnabled") private var linterEnabled = true
    @State private var showResetConfirmation = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            content
                .navigationTitle("About")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        #else
        ZStack(alignment: .topTrailing) {
            content

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .padding(16)
        }
        #endif
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer()

            appIcon
                .padding(.bottom, 20)

            Text("Vera")
                .font(.title2.weight(.semibold))

            Text("Version \(version)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer().frame(height: 28)

            Text(
                "Vera browses and edits any Markdown file anywhere in your iCloud Drive " +
                "or local storage — no dedicated folder, no vault, no configuration. " +
                "Your file system is the source of truth; Vera is just a window into it.\n\n" +
                "The name Vera carries two meanings: the Latin vera, meaning truth — " +
                "and the Spanish vera, meaning side or shore, as in \"ven a mi vera\" " +
                "(come to my side). A truthful companion that stays close to your files.\n\n" +
                "Part of the Mira ecosystem."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .frame(maxWidth: 360)

            Spacer().frame(height: 24)

            VStack(spacing: 12) {
                Toggle("Markdown Linter", isOn: $linterEnabled)
                    .font(.subheadline)
                    .frame(maxWidth: 280)

                if onReset != nil {
                    Button("Reset Vera…", role: .destructive) {
                        showResetConfirmation = true
                    }
                    .font(.subheadline)
                }
            }

            Spacer().frame(height: 20)

            HStack(spacing: 16) {
                if let privacyURL = URL(string: "https://github.com/mabaeyens/vera-apps/blob/main/PRIVACY.md") {
                    Link("Privacy", destination: privacyURL)
                }
                Text("·").foregroundStyle(.tertiary)
                if let repoURL = URL(string: "https://github.com/mabaeyens/vera-apps") {
                    Link("Source", destination: repoURL)
                }
            }
            .font(.footnote)

            Text("No account · no servers · nothing sent anywhere")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "Reset Vera?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                onReset?()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will clear your folder selection. Your files are not deleted.")
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        #if os(iOS)
        if let image = loadAppIcon() {
            Image(uiImage: image)
                .resizable()
                .frame(width: 100, height: 100)
                .clipShape(.rect(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.green)
                .frame(width: 100, height: 100)
        }
        #else
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .frame(width: 100, height: 100)
            .clipShape(.rect(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        #endif
    }

    #if os(iOS)
    private func loadAppIcon() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last,
           let image = UIImage(named: name) {
            return image
        }
        return UIImage(named: "AppIcon")
    }
    #endif
}

#Preview {
    AboutView()
        .frame(width: 480, height: 560)
}
