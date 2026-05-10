import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                Spacer()

                appIcon
                    .padding(.bottom, 20)

                Text("Vera")
                    .font(.system(size: 28, weight: .semibold))

                Text("Version \(version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Spacer().frame(height: 28)

                Text(
                    "Vera browses and edits any Markdown file anywhere in your iCloud Drive " +
                    "or local storage — no dedicated folder, no vault, no configuration. " +
                    "Your file system is the source of truth; Vera is just a window into it.\n\n" +
                    "The name Vera is the Latin word for \"true\" and the Portuguese word " +
                    "for \"real\" — a quiet editor that stays out of the way of your files.\n\n" +
                    "Part of the Mira ecosystem."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 360)

                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        #if os(iOS)
        Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
            .resizable()
            .frame(width: 100, height: 100)
            .clipShape(.rect(cornerRadius: 22, style: .continuous))
        #else
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .frame(width: 100, height: 100)
            .clipShape(.rect(cornerRadius: 22, style: .continuous))
        #endif
    }
}

#Preview {
    AboutView()
        .frame(width: 480, height: 560)
}
