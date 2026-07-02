import CryptoKit
import Foundation

enum PKCE {
  private static let allowedCharacters = Array(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

  static func generateCodeVerifier(length: Int = 64) -> String {
    var verifier = ""
    verifier.reserveCapacity(length)
    for _ in 0..<length {
      verifier.append(allowedCharacters.randomElement()!)
    }
    return verifier
  }

  static func codeChallenge(for verifier: String) -> String {
    let digest = SHA256.hash(data: Data(verifier.utf8))
    return Data(digest)
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  static func generateState(length: Int = 16) -> String {
    generateCodeVerifier(length: length)
  }
}
