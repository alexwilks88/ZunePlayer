import Foundation

/// Minimum scopes for the home-screen library sections (Artists, Albums, Songs, Playlists).
/// Paths and scope requirements are defined in the Spotify OpenAPI spec.
enum SpotifyScopes {
  static let homeLibrary: [String] = [
    "user-library-read",           // GET /me/albums, GET /me/tracks
    "user-follow-read",            // GET /me/following?type=artist
    "playlist-read-private",       // GET /me/playlists (private playlists)
    "playlist-read-collaborative", // GET /me/playlists (collaborative playlists)
  ]

  static var authorizationValue: String {
    homeLibrary.joined(separator: " ")
  }
}
