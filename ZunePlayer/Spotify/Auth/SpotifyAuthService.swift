import Foundation
import Observation

@MainActor
@Observable
final class SpotifyAuthService {
  private(set) var isAuthenticated = false
  private(set) var isLoading = false
  private(set) var lastError: String?

  private var tokens: SpotifyStoredTokens?
  private var pendingCodeVerifier: String?
  private var pendingState: String?
  private var isSigningIn = false

  private let webAuthSession = SpotifyWebAuthSession()
  private let urlSession: URLSession

  init(urlSession: URLSession = .shared) {
    self.urlSession = urlSession
  }

  func restoreSession() async {
    do {
      if let stored = try SpotifyTokenStore.load() {
        tokens = stored
        if stored.shouldRefresh {
          try await refreshTokens()
        }
        isAuthenticated = true
      }
    } catch {
      lastError = error.localizedDescription
      isAuthenticated = false
    }
  }

  func signIn() async {
    isLoading = true
    lastError = nil
    defer { isLoading = false }

    guard SpotifyConfig.isConfigured,
      let clientID = SpotifyConfig.clientID,
      let redirectURI = SpotifyConfig.redirectURI,
      let redirectHost = SpotifyConfig.redirectHost
    else {
      lastError = SpotifyAuthError.notConfigured.errorDescription
      return
    }

    do {
      let codeVerifier = PKCE.generateCodeVerifier()
      let codeChallenge = PKCE.codeChallenge(for: codeVerifier)
      let state = PKCE.generateState()

      pendingCodeVerifier = codeVerifier
      pendingState = state
      isSigningIn = true
      defer {
        isSigningIn = false
        pendingCodeVerifier = nil
        pendingState = nil
      }

      var components = URLComponents(url: SpotifyEndpoints.authorize, resolvingAgainstBaseURL: false)!
      components.queryItems = [
        URLQueryItem(name: "client_id", value: clientID),
        URLQueryItem(name: "response_type", value: "code"),
        URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
        URLQueryItem(name: "scope", value: SpotifyScopes.authorizationValue),
        URLQueryItem(name: "state", value: state),
        URLQueryItem(name: "code_challenge_method", value: "S256"),
        URLQueryItem(name: "code_challenge", value: codeChallenge),
      ]

      guard let authorizationURL = components.url else {
        throw SpotifyAuthError.notConfigured
      }

      // Let SwiftUI attach the presentation anchor window before opening the auth sheet.
      await Task.yield()
      try await Task.sleep(for: .milliseconds(150))

      let callbackURL = try await webAuthSession.authenticate(
        authorizationURL: authorizationURL,
        callbackHost: redirectHost,
        callbackPath: SpotifyConfig.redirectPath
      )

      try await handleAuthorizationCallback(callbackURL)
    } catch let error as SpotifyAuthError {
      if case .sessionCancelled = error {
        try? await Task.sleep(for: .seconds(2))
      }
      if !isAuthenticated {
        lastError = error.errorDescription
      }
    } catch {
      if !isAuthenticated {
        lastError = error.localizedDescription
      }
    }
  }

  func handleOpenURL(_ url: URL) async {
    guard isSigningIn, SpotifyConfig.matchesRedirectURI(url) else { return }

    do {
      try await handleAuthorizationCallback(url)
      isSigningIn = false
      lastError = nil
    } catch let error as SpotifyAuthError {
      lastError = error.errorDescription
    } catch {
      lastError = error.localizedDescription
    }
  }

  func signOut() {
    tokens = nil
    isAuthenticated = false
    lastError = nil
    try? SpotifyTokenStore.delete()
  }

  func validAccessToken() async throws -> String {
    guard var current = tokens else {
      throw SpotifyAuthError.refreshTokenExpired
    }

    if current.shouldRefresh {
      try await refreshTokens()
      guard let refreshed = tokens else {
        throw SpotifyAuthError.refreshTokenExpired
      }
      current = refreshed
    }

    return current.accessToken
  }

  private func handleAuthorizationCallback(_ callbackURL: URL) async throws {
    let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)

    if let error = components?.queryItems?.first(where: { $0.name == "error" })?.value {
      throw SpotifyAuthError.authorizationDenied(error)
    }

    guard let returnedState = components?.queryItems?.first(where: { $0.name == "state" })?.value,
      returnedState == pendingState
    else {
      throw SpotifyAuthError.stateMismatch
    }

    guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value else {
      throw SpotifyAuthError.missingAuthorizationCode
    }

    guard let codeVerifier = pendingCodeVerifier else {
      throw SpotifyAuthError.missingCodeVerifier
    }

    let response = try await exchangeCodeForTokens(code: code, codeVerifier: codeVerifier)
    try persistTokenResponse(response, existingRefreshToken: nil)
    isAuthenticated = true
  }

  private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> SpotifyTokenResponse {
    var request = URLRequest(url: SpotifyEndpoints.token)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    guard let clientID = SpotifyConfig.clientID,
      let redirectURI = SpotifyConfig.redirectURI
    else {
      throw SpotifyAuthError.notConfigured
    }

    let body = [
      "grant_type": "authorization_code",
      "code": code,
      "redirect_uri": redirectURI.absoluteString,
      "client_id": clientID,
      "code_verifier": codeVerifier,
    ]
    request.httpBody = formEncoded(body)

    let (data, response) = try await urlSession.data(for: request)
    try validateTokenHTTPResponse(data: data, response: response)
    return try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
  }

  private func refreshTokens() async throws {
    guard let refreshToken = tokens?.refreshToken else {
      throw SpotifyAuthError.refreshTokenExpired
    }

    var request = URLRequest(url: SpotifyEndpoints.token)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    guard let clientID = SpotifyConfig.clientID else {
      throw SpotifyAuthError.notConfigured
    }

    let body = [
      "grant_type": "refresh_token",
      "refresh_token": refreshToken,
      "client_id": clientID,
    ]
    request.httpBody = formEncoded(body)

    let (data, response) = try await urlSession.data(for: request)

    if let http = response as? HTTPURLResponse, http.statusCode == 400,
      let tokenError = try? JSONDecoder().decode(SpotifyTokenErrorResponse.self, from: data),
      tokenError.error == "invalid_grant"
    {
      signOut()
      throw SpotifyAuthError.refreshTokenExpired
    }

    try validateTokenHTTPResponse(data: data, response: response)
    let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
    try persistTokenResponse(tokenResponse, existingRefreshToken: refreshToken)
  }

  private func persistTokenResponse(
    _ response: SpotifyTokenResponse,
    existingRefreshToken: String?
  ) throws {
    guard let refreshToken = response.refreshToken ?? existingRefreshToken else {
      throw SpotifyAuthError.tokenExchangeFailed("No refresh token was returned.")
    }

    let stored = SpotifyStoredTokens(
      accessToken: response.accessToken,
      refreshToken: refreshToken,
      expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)),
      scope: response.scope
    )

    tokens = stored
    try SpotifyTokenStore.save(stored)
  }

  private func validateTokenHTTPResponse(data: Data, response: URLResponse) throws {
    guard let http = response as? HTTPURLResponse else { return }

    guard (200...299).contains(http.statusCode) else {
      if let tokenError = try? JSONDecoder().decode(SpotifyTokenErrorResponse.self, from: data) {
        if tokenError.error == "invalid_grant" {
          signOut()
          throw SpotifyAuthError.refreshTokenExpired
        }
        let description = tokenError.errorDescription ?? tokenError.error
        throw SpotifyAuthError.tokenExchangeFailed(description)
      }
      throw SpotifyAuthError.tokenExchangeFailed("HTTP \(http.statusCode)")
    }
  }

  private func formEncoded(_ values: [String: String]) -> Data {
    let query = values
      .map { key, value in
        "\(formEncode(key))=\(formEncode(value))"
      }
      .joined(separator: "&")
    return Data(query.utf8)
  }

  private func formEncode(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
  }
}
