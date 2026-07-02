import Foundation

/// Typed accessors for home-screen library endpoints defined in the Spotify OpenAPI spec.
struct SpotifyLibraryService {
  private let api: SpotifyAPIClient

  init(api: SpotifyAPIClient) {
    self.api = api
  }

  func fetchPlaylists(limit: Int = 20, offset: Int = 0) async throws -> Data {
    try await api.request(
      path: SpotifyEndpoints.currentUserPlaylists,
      queryItems: [
        URLQueryItem(name: "limit", value: String(limit)),
        URLQueryItem(name: "offset", value: String(offset)),
      ]
    )
  }

  func fetchFollowedArtists(limit: Int = 20, after: String? = nil) async throws -> Data {
    var items = [
      URLQueryItem(name: "type", value: "artist"),
      URLQueryItem(name: "limit", value: String(limit)),
    ]
    if let after {
      items.append(URLQueryItem(name: "after", value: after))
    }
    return try await api.request(path: SpotifyEndpoints.followedArtists, queryItems: items)
  }

  func fetchSavedAlbums(limit: Int = 20, offset: Int = 0) async throws -> Data {
    try await api.request(
      path: SpotifyEndpoints.savedAlbums,
      queryItems: [
        URLQueryItem(name: "limit", value: String(limit)),
        URLQueryItem(name: "offset", value: String(offset)),
      ]
    )
  }

  func fetchSavedTracks(limit: Int = 20, offset: Int = 0) async throws -> Data {
    try await api.request(
      path: SpotifyEndpoints.savedTracks,
      queryItems: [
        URLQueryItem(name: "limit", value: String(limit)),
        URLQueryItem(name: "offset", value: String(offset)),
      ]
    )
  }
}
