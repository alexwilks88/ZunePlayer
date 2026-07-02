import SwiftUI

@MainActor
enum AppDependencies {
  static let authService = SpotifyAuthService()
  static let apiClient = SpotifyAPIClient(authService: authService)
  static let libraryService = SpotifyLibraryService(api: apiClient)
}
