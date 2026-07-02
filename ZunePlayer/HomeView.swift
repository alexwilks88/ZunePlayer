import SwiftUI

struct HomeView: View {
  private let menuItems = ["Artists", "Albums", "Songs", "Playlists"]

  var body: some View {
    ZStack {
      ZuneTheme.background
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 4) {
        ForEach(menuItems, id: \.self) { item in
          Text(item)
            .font(.zuneMenu)
            .foregroundStyle(ZuneTheme.foreground)
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
  HomeView()
}
