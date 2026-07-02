import SwiftUI

struct LoginView: View {
  @Environment(SpotifyAuthService.self) private var authService

  var body: some View {
    ZStack {
      ZuneTheme.background
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 24) {
        Text("Zune Player")
          .font(.zuneMenu)
          .foregroundStyle(ZuneTheme.foreground)

        Text("Connect your Spotify account to browse your library.")
          .font(.custom("Segoe UI", size: 18))
          .foregroundStyle(ZuneTheme.foreground.opacity(0.7))

        Button {
          Task { await authService.signIn() }
        } label: {
          Group {
            if authService.isLoading {
              ProgressView()
                .tint(.black)
            } else {
              Text("Connect to Spotify")
                .font(.custom("Segoe UI", size: 22))
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .background(ZuneTheme.foreground)
        .foregroundStyle(.black)
        .disabled(authService.isLoading)

        if let error = authService.lastError {
          Text(error)
            .font(.custom("Segoe UI", size: 16))
            .foregroundStyle(.red.opacity(0.9))
        } else if !SpotifyConfig.isConfigured {
          Text("Copy SpotifySecrets.example.plist to SpotifySecrets.plist and add your Spotify client ID and HTTPS redirect URI.")
            .font(.custom("Segoe UI", size: 16))
            .foregroundStyle(ZuneTheme.foreground.opacity(0.6))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(.horizontal, 28)
      .padding(.top, 72)
    }
    .preferredColorScheme(.dark)
  }
}

#Preview {
  LoginView()
    .environment(SpotifyAuthService())
}
