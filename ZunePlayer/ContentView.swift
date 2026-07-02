import SwiftUI

struct ContentView: View {
  @Environment(SpotifyAuthService.self) private var authService

  var body: some View {
    Group {
      if authService.isAuthenticated {
        HomeView()
      } else {
        LoginView()
      }
    }
    .background {
      #if os(iOS)
      SpotifyAuthWindowAccessor()
      #endif
    }
    .task {
      await authService.restoreSession()
    }
  }
}

#Preview {
  ContentView()
    .environment(SpotifyAuthService())
}
