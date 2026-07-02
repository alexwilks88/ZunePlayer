import Foundation

struct SpotifyTokenResponse: Decodable {
  let accessToken: String
  let tokenType: String
  let scope: String
  let expiresIn: Int
  let refreshToken: String?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case tokenType = "token_type"
    case scope
    case expiresIn = "expires_in"
    case refreshToken = "refresh_token"
  }
}

struct SpotifyTokenErrorResponse: Decodable {
  let error: String
  let errorDescription: String?

  enum CodingKeys: String, CodingKey {
    case error
    case errorDescription = "error_description"
  }
}

struct SpotifyStoredTokens: Codable, Sendable {
  let accessToken: String
  let refreshToken: String
  let expiresAt: Date
  let scope: String

  var isExpired: Bool {
    expiresAt <= Date()
  }

  var shouldRefresh: Bool {
    expiresAt.timeIntervalSinceNow < 60
  }
}

/// Error object from the Spotify Web API OpenAPI schema (`ErrorObject`).
struct SpotifyErrorObject: Decodable, Sendable {
  let status: Int
  let message: String
}

struct SpotifyAPIErrorBody: Decodable, Sendable {
  let error: SpotifyErrorObject
}

enum SpotifyAuthError: LocalizedError, Sendable {
  case notConfigured
  case authorizationDenied(String)
  case missingAuthorizationCode
  case missingCodeVerifier
  case stateMismatch
  case invalidGrant(String)
  case tokenExchangeFailed(String)
  case refreshTokenExpired
  case sessionCancelled

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      "Spotify is not configured. Add SpotifySecrets.plist with your client ID and redirect URI."
    case .authorizationDenied(let reason):
      "Spotify authorization was denied: \(reason)"
    case .missingAuthorizationCode:
      "Spotify did not return an authorization code."
    case .missingCodeVerifier:
      "PKCE code verifier was missing. Please try signing in again."
    case .stateMismatch:
      "Spotify authorization state did not match. Please try signing in again."
    case .invalidGrant(let description):
      description
    case .tokenExchangeFailed(let description):
      "Could not complete Spotify sign-in: \(description)"
    case .refreshTokenExpired:
      "Your Spotify session has expired. Please sign in again."
    case .sessionCancelled:
      "Spotify sign-in was cancelled."
    }
  }
}

enum SpotifyAPIError: LocalizedError, Sendable {
  case unauthorized(String)
  case forbidden(String)
  case notFound(String)
  case badRequest(String)
  case rateLimited(retryAfter: TimeInterval, message: String)
  case serverError(statusCode: Int, message: String)
  case unexpectedStatus(statusCode: Int, message: String)
  case decodingFailed(String)
  case network(Error)

  var errorDescription: String? {
    switch self {
    case .unauthorized(let message): message
    case .forbidden(let message): message
    case .notFound(let message): message
    case .badRequest(let message): message
    case .rateLimited(_, let message): message
    case .serverError(_, let message): message
    case .unexpectedStatus(_, let message): message
    case .decodingFailed(let message): message
    case .network(let error): error.localizedDescription
    }
  }
}
