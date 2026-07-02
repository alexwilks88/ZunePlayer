import Foundation

actor SpotifyAPIClient {
  private let authService: SpotifyAuthService
  private let urlSession: URLSession
  private var rateLimitUntil: Date?

  init(authService: SpotifyAuthService, urlSession: URLSession = .shared) {
    self.authService = authService
    self.urlSession = urlSession
  }

  func request(
    path: String,
    method: String = "GET",
    queryItems: [URLQueryItem] = [],
    body: Data? = nil,
    retryCount: Int = 0
  ) async throws -> Data {
    if let rateLimitUntil, rateLimitUntil > Date() {
      let delay = rateLimitUntil.timeIntervalSinceNow
      try await Task.sleep(for: .seconds(delay))
    }

    let accessToken = try await authService.validAccessToken()

    var components = URLComponents(url: SpotifyEndpoints.apiBase.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
    if !queryItems.isEmpty {
      components.queryItems = queryItems
    }

    guard let url = components.url else {
      throw SpotifyAPIError.badRequest("Invalid request URL.")
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    if body != nil {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    request.httpBody = body

    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await urlSession.data(for: request)
    } catch {
      throw SpotifyAPIError.network(error)
    }

    guard let http = response as? HTTPURLResponse else {
      throw SpotifyAPIError.unexpectedStatus(statusCode: -1, message: "Invalid response.")
    }

    switch http.statusCode {
    case 200...299:
      return data

    case 401:
      let message = parseErrorMessage(from: data) ?? "Bad or expired token. Please sign in again."
      throw SpotifyAPIError.unauthorized(message)

    case 403:
      let message = parseErrorMessage(from: data) ?? "Spotify rejected this request."
      throw SpotifyAPIError.forbidden(message)

    case 404:
      let message = parseErrorMessage(from: data) ?? "The requested resource was not found."
      throw SpotifyAPIError.notFound(message)

    case 400:
      let message = parseErrorMessage(from: data) ?? "The request was malformed."
      throw SpotifyAPIError.badRequest(message)

    case 429:
      let retryAfter = parseRetryAfter(http: http, attempt: retryCount)
      rateLimitUntil = Date().addingTimeInterval(retryAfter)
      let message = parseErrorMessage(from: data) ?? "Spotify rate limit exceeded."

      guard retryCount < 3 else {
        throw SpotifyAPIError.rateLimited(retryAfter: retryAfter, message: message)
      }

      try await Task.sleep(for: .seconds(retryAfter))
      return try await self.request(
        path: path,
        method: method,
        queryItems: queryItems,
        body: body,
        retryCount: retryCount + 1
      )

    case 500...599:
      let message = parseErrorMessage(from: data) ?? "Spotify server error."
      throw SpotifyAPIError.serverError(statusCode: http.statusCode, message: message)

    default:
      let message = parseErrorMessage(from: data) ?? "Unexpected Spotify API response."
      throw SpotifyAPIError.unexpectedStatus(statusCode: http.statusCode, message: message)
    }
  }

  func decode<T: Decodable>(
    _ type: T.Type,
    path: String,
    queryItems: [URLQueryItem] = []
  ) async throws -> T {
    let data = try await request(path: path, queryItems: queryItems)
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw SpotifyAPIError.decodingFailed(error.localizedDescription)
    }
  }

  private func parseErrorMessage(from data: Data) -> String? {
    if let body = try? JSONDecoder().decode(SpotifyAPIErrorBody.self, from: data) {
      return body.error.message
    }
    if let tokenError = try? JSONDecoder().decode(SpotifyTokenErrorResponse.self, from: data) {
      return tokenError.errorDescription ?? tokenError.error
    }
    return nil
  }

  private func parseRetryAfter(http: HTTPURLResponse, attempt: Int) -> TimeInterval {
    if let header = http.value(forHTTPHeaderField: "Retry-After"), let seconds = TimeInterval(header) {
      return seconds
    }

    // Exponential backoff fallback when Retry-After is absent.
    return min(pow(2.0, Double(attempt + 1)), 60)
  }
}
