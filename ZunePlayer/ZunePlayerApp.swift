import CoreText
import SwiftUI

@main
struct ZunePlayerApp: App {
  init() {
    registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(AppDependencies.authService)
        .onOpenURL { url in
          Task { await AppDependencies.authService.handleOpenURL(url) }
        }
    }
  }

  private func registerFonts() {
    guard let url = Bundle.main.url(forResource: "SegoeUI", withExtension: "ttf", subdirectory: "Fonts")
      ?? Bundle.main.url(forResource: "SegoeUI", withExtension: "ttf")
    else { return }
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
  }
}
