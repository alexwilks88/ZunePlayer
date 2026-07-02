import Foundation

/// Endpoint paths from https://developer.spotify.com/reference/web-api/open-api-schema.yaml
enum SpotifyEndpoints {
  static let apiBase = URL(string: "https://api.spotify.com/v1")!
  static let authorize = URL(string: "https://accounts.spotify.com/authorize")!
  static let token = URL(string: "https://accounts.spotify.com/api/token")!

  // Library
  static let library = "/me/library"
  static let libraryContains = "/me/library/contains"

  // Artists
  static let followedArtists = "/me/following"

  // Albums
  static let savedAlbums = "/me/albums"

  // Tracks
  static let savedTracks = "/me/tracks"

  // Playlists
  static let currentUserPlaylists = "/me/playlists"

  static func playlistItems(id: String) -> String {
    "/playlists/\(id)/items"
  }
}
