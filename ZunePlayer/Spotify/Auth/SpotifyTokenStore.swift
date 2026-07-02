import Foundation
import Security

enum SpotifyTokenStore {
  private static let service = "com.zuneplayer.spotify.tokens"
  private static let account = "current-user"

  static func save(_ tokens: SpotifyStoredTokens) throws {
    let data = try JSONEncoder().encode(tokens)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]

    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecItemNotFound {
      var addQuery = query
      addQuery[kSecValueData as String] = data
      addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        throw KeychainError.unhandled(addStatus)
      }
    } else if updateStatus != errSecSuccess {
      throw KeychainError.unhandled(updateStatus)
    }
  }

  static func load() throws -> SpotifyStoredTokens? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = item as? Data else {
      throw KeychainError.unhandled(status)
    }
    return try JSONDecoder().decode(SpotifyStoredTokens.self, from: data)
  }

  static func delete() throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.unhandled(status)
    }
  }

  enum KeychainError: LocalizedError {
    case unhandled(OSStatus)

    var errorDescription: String? {
      switch self {
      case .unhandled(let status):
        "Keychain error (\(status))"
      }
    }
  }
}
