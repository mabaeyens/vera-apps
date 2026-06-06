import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    private let brand = Color("BrandTeal", bundle: nil)

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(brand)
                    .frame(width: 80, height: 80)
                Image(systemName: "doc.text")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 24)

            Text("Welcome to Vera")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Text("Browse and edit Markdown files anywhere in iCloud Drive or local storage.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

            VStack(alignment: .leading, spacing: 20) {
                OnboardingFeatureRow(
                    icon: "folder",
                    title: "Your files, your structure",
                    description: "Open any folder — no vault, no import step."
                )
                OnboardingFeatureRow(
                    icon: "eye",
                    title: "Beautiful reading",
                    description: "Markdown renders cleanly with headers, lists, and code blocks."
                )
                OnboardingFeatureRow(
                    icon: "pencil",
                    title: "Syntax-highlighted editing",
                    description: "Edit with live color highlighting across light and dark mode."
                )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)

            Text("Vera only accesses the folder you choose. No account required.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

            Button {
                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                dismiss()
            } label: {
                Text("Choose a Folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)

            Spacer()
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
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color("BrandTeal", bundle: nil))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
