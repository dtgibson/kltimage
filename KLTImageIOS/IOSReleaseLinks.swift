import Foundation

/// Only verified public destinations belong in the release configuration.
/// Missing owner-supplied URLs are a submission blocker, never placeholder links.
enum IOSReleaseLinks {
    static var privacy: URL? { publicURL(key: "KLTPrivacyPolicyURL") }
    static var support: URL? { publicURL(key: "KLTSupportURL") }

    private static func publicURL(key: String) -> URL? {
        guard let string = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: string), url.scheme == "https", let host = url.host,
              !host.hasSuffix(".ts.net"), host != "localhost", !host.hasSuffix(".local") else { return nil }
        return url
    }
}
