import Foundation

enum SpotifyConfig {
  private static let secrets: [String: Any] = {
    guard
      let url = Bundle.main.url(forResource: "SpotifySecrets", withExtension: "plist"),
      let data = try? Data(contentsOf: url),
      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    else {
      return [:]
    }
    return plist
  }()

  static var isConfigured: Bool {
    clientID != nil && redirectURI != nil
  }

  static var clientID: String? {
    guard let value = secrets["SPOTIFY_CLIENT_ID"] as? String,
      !value.isEmpty,
      value != "YOUR_SPOTIFY_CLIENT_ID"
    else { return nil }
    return value
  }

  static var redirectURI: URL? {
    guard let value = secrets["SPOTIFY_REDIRECT_URI"] as? String,
      let url = URL(string: value),
      url.scheme == "https" || value.hasPrefix("http://127.0.0.1")
    else { return nil }
    return url
  }

  static var redirectHost: String? {
    redirectURI?.host
  }

  static var redirectPath: String {
    guard let path = redirectURI?.path, !path.isEmpty else { return "/" }
    return path
  }

  static var callbackURLScheme: String {
    redirectURI?.scheme ?? "https"
  }

  static func matchesRedirectURI(_ url: URL) -> Bool {
    guard let redirectURI, let host = redirectURI.host else { return false }
    return url.host == host && url.path == redirectURI.path
  }
}
