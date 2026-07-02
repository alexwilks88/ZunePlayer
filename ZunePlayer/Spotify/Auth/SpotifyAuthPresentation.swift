#if os(iOS)
import AuthenticationServices
import SwiftUI
import UIKit

@MainActor
enum SpotifyAuthPresentation {
  static weak var anchorWindow: UIWindow?

  static func resolveAnchor() -> ASPresentationAnchor {
    if let anchorWindow {
      return anchorWindow
    }

    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
      return keyWindow
    }

    if let firstWindow = scenes.first?.windows.first {
      return firstWindow
    }

    return ASPresentationAnchor()
  }
}

struct SpotifyAuthWindowAccessor: UIViewRepresentable {
  func makeUIView(context: Context) -> UIView {
    let view = UIView(frame: .zero)
    view.isUserInteractionEnabled = false
    DispatchQueue.main.async {
      SpotifyAuthPresentation.anchorWindow = view.window
    }
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    SpotifyAuthPresentation.anchorWindow = uiView.window
  }
}
#endif
