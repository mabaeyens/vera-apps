import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Theme.Space.xl)

            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(Theme.brand)
                    .frame(width: 88, height: 88)
                Image(systemName: "doc.text")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .padding(.bottom, Theme.Space.xl)

            Text("Welcome to Vera")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, Theme.Space.s)

            Text("A clean, native home for your Markdown — straight from iCloud Drive or any local folder.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.Space.xxl)
                .padding(.bottom, Theme.Space.xl + Theme.Space.l)

            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                OnboardingFeatureRow(
                    icon: "folder",
                    title: "Your files, your structure",
                    description: "Open any folder — no vault, no import, no lock-in."
                )
                OnboardingFeatureRow(
                    icon: "eye",
                    title: "Beautiful reading",
                    description: "Headers, lists, tables and code blocks, rendered cleanly."
                )
                OnboardingFeatureRow(
                    icon: "curlybraces",
                    title: "Built for developers",
                    description: "Syntax-highlighted editing, tabs, and a Markdown linter."
                )
            }
            .padding(.horizontal, Theme.Space.xxl)
            .padding(.bottom, Theme.Space.xl + Theme.Space.l)

            Text("Private by design: no account, no servers, nothing sent anywhere.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.xxl)
                .padding(.bottom, Theme.Space.xl)

            Button {
                UserDefaults.standard.set(true, forKey: Defaults.Key.hasSeenOnboarding)
                dismiss()
            } label: {
                Text("Choose a Folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, Theme.Space.xxl)

            Spacer(minLength: Theme.Space.xl)
        }
        #if os(iOS)
        .interactiveDismissDisabled()
        #endif
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.l) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Space.xs / 2) {
                Text(title).font(.subheadline.bold())
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
