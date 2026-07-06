import Foundation

/// OAuth Device Flow for a GitHub App (no client secret needed).
///
/// One-time setup: register a GitHub App at github.com/settings/apps/new
/// with Contents: Read+Write, Metadata: Read-only, Device Flow enabled,
/// and user-token expiration disabled. Paste the client ID below.
enum GitHubApp {
    /// Public client ID of the Vera GitHub App. Not a secret — safe to ship.
    static let clientID = "Iv23liYBI7xOIKdihhqu"
}

enum DeviceAuthError: LocalizedError {
    case noClientID
    case accessDenied
    case expiredToken
    case badResponse

    var errorDescription: String? {
        switch self {
        case .noClientID:    return "GitHub App is not configured."
        case .accessDenied:  return "Authorization was denied."
        case .expiredToken:  return "The code expired. Try again."
        case .badResponse:   return "Unexpected response from GitHub."
        }
    }
}

struct DeviceCodeResponse {
    let deviceCode: String
    let userCode: String
    let verificationURI: URL
    let expiresIn: Int
    let interval: Int
}

/// Performs the two-step GitHub OAuth Device Flow.
struct GitHubDeviceAuth {

    private static let deviceCodeURLString = "https://github.com/login/device/code"
    private static let accessTokenURLString = "https://github.com/login/oauth/access_token"

    /// Step 1: request a device_code / user_code pair.
    func requestDeviceCode() async throws -> DeviceCodeResponse {
        guard !GitHubApp.clientID.isEmpty else { throw DeviceAuthError.noClientID }
        guard let deviceCodeURL = URL(string: Self.deviceCodeURLString) else { throw DeviceAuthError.badResponse }
        var req = URLRequest(url: deviceCodeURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "client_id=\(GitHubApp.clientID)".data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deviceCode = json["device_code"] as? String,
              let userCode   = json["user_code"]   as? String,
              let uriStr     = json["verification_uri"] as? String,
              let uri        = URL(string: uriStr),
              let expiresIn  = json["expires_in"] as? Int,
              let interval   = json["interval"]   as? Int
        else { throw DeviceAuthError.badResponse }
        return DeviceCodeResponse(
            deviceCode: deviceCode, userCode: userCode,
            verificationURI: uri, expiresIn: expiresIn, interval: interval
        )
    }

    /// Step 2: poll until the user authorises or the code expires.
    /// Returns the bearer access token on success.
    func pollForToken(deviceCode: String, interval: Int) async throws -> String {
        var pollInterval = interval
        while true {
            try await Task.sleep(for: .seconds(pollInterval))
            if Task.isCancelled { throw CancellationError() }

            guard let accessTokenURL = URL(string: Self.accessTokenURLString) else { throw DeviceAuthError.badResponse }
            var req = URLRequest(url: accessTokenURL)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let body = "client_id=\(GitHubApp.clientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
            req.httpBody = body.data(using: .utf8)
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw DeviceAuthError.badResponse
            }

            if let token = json["access_token"] as? String { return token }
            switch json["error"] as? String {
            case "authorization_pending": continue
            case "slow_down":
                pollInterval += (json["interval"] as? Int ?? 5)
            case "expired_token": throw DeviceAuthError.expiredToken
            case "access_denied":  throw DeviceAuthError.accessDenied
            default: throw DeviceAuthError.badResponse
            }
        }
    }
}
