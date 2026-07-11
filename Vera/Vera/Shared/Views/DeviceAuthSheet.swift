import SwiftUI

/// Guides the user through the GitHub OAuth Device Flow.
/// Shows the user_code in large monospaced text, a "Copy & Open GitHub" button,
/// and a spinner while polling. Calls `onSuccess` with the access token.
struct DeviceAuthSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSuccess: (String) -> Void

    @State private var phase: Phase = .requesting
    @State private var deviceCode: DeviceCodeResponse?
    @State private var pollTask: Task<Void, Never>?
    @State private var errorText: String?

    enum Phase { case requesting, waiting, done }

    /// GitHub's generic "manage app installations" page — lists every GitHub App
    /// installed on the user's account and lets them add/remove repo access. Used
    /// instead of the app-specific `github.com/apps/<slug>/installations/new` deep
    /// link since it needs no slug and works whether or not the App is installed yet.
    static let installationsURL = URL(string: "https://github.com/settings/installations")!

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .requesting:
                    ProgressView("Connecting to GitHub…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .waiting:
                    waitingView
                case .done:
                    VStack(spacing: 16) {
                        ContentUnavailableView {
                            Label("Signed In", systemImage: "checkmark.circle")
                        } description: {
                            Text("One more step: choose which repos Vera can access.")
                        }
                        Button {
                            openURL(Self.installationsURL)
                        } label: {
                            Label("Open GitHub to Select Repos", systemImage: "safari")
                        }
                        .buttonStyle(.borderedProminent)
                        Text("Signing in authorizes your GitHub account, but the Vera app still needs to be installed on the specific repos you want to browse — including any private ones.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
            .navigationTitle("Sign In with GitHub")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(phase == .done ? "Done" : "Cancel") {
                        pollTask?.cancel()
                        dismiss()
                    }
                }
            }
        }
        .task { await startFlow() }
        .onDisappear { pollTask?.cancel() }
    }

    private var waitingView: some View {
        VStack(spacing: 24) {
            if let code = deviceCode {
                Text("Enter this code at GitHub")
                    .font(.headline)
                Text(code.userCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .padding()
                    .background(.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                Button {
                    UIPasteboard_copy(code.userCode)
                    openURL(code.verificationURI)
                } label: {
                    Label("Copy Code & Open GitHub", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for approval…").foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                Button("Try Again") { Task { await startFlow() } }
                    .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .multilineTextAlignment(.center)
    }

    private func startFlow() async {
        phase = .requesting
        errorText = nil
        let auth = GitHubDeviceAuth()
        do {
            let response = try await auth.requestDeviceCode()
            deviceCode = response
            phase = .waiting
            pollTask?.cancel()
            pollTask = Task {
                do {
                    let token = try await auth.pollForToken(
                        deviceCode: response.deviceCode,
                        interval: response.interval
                    )
                    guard !Task.isCancelled else { return }
                    onSuccess(token)
                    phase = .done
                } catch is CancellationError {
                    // dismissed — no-op
                } catch {
                    guard !Task.isCancelled else { return }
                    errorText = error.localizedDescription
                }
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    // Cross-platform clipboard + URL open helpers.
    private func UIPasteboard_copy(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    private func openURL(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
}
