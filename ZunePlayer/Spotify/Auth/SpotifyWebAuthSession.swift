import AuthenticationServices
import Foundation

@MainActor
final class SpotifyWebAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
  private var session: ASWebAuthenticationSession?

  func authenticate(
    authorizationURL: URL,
    callbackHost: String,
    callbackPath: String
  ) async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      let session: ASWebAuthenticationSession

      if #available(iOS 17.4, macOS 14.4, *) {
        session = ASWebAuthenticationSession(
          url: authorizationURL,
          callback: .https(host: callbackHost, path: callbackPath)
        ) { callbackURL, error in
          Self.resume(continuation: continuation, callbackURL: callbackURL, error: error)
        }
      } else {
        session = ASWebAuthenticationSession(
          url: authorizationURL,
          callbackURLScheme: "https"
        ) { callbackURL, error in
          Self.resume(continuation: continuation, callbackURL: callbackURL, error: error)
        }
      }

      session.presentationContextProvider = self
      session.prefersEphemeralWebBrowserSession = false
      self.session = session

      // Defer start so SwiftUI has finished presenting the anchor window.
      DispatchQueue.main.async {
        guard session.start() else {
          continuation.resume(
            throwing: SpotifyAuthError.tokenExchangeFailed("Could not present Spotify sign-in.")
          )
          return
        }
      }
    }
  }

  private static func resume(
    continuation: CheckedContinuation<URL, Error>,
    callbackURL: URL?,
    error: Error?
  ) {
    if let error {
      let nsError = error as NSError
      if nsError.domain == ASWebAuthenticationSessionErrorDomain,
        nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
      {
        continuation.resume(throwing: SpotifyAuthError.sessionCancelled)
        return
      }
      continuation.resume(throwing: error)
      return
    }

    guard let callbackURL else {
      continuation.resume(throwing: SpotifyAuthError.missingAuthorizationCode)
      return
    }

    continuation.resume(returning: callbackURL)
  }

  nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    #if os(iOS)
    if Thread.isMainThread {
      return MainActor.assumeIsolated {
        SpotifyAuthPresentation.resolveAnchor()
      }
    }

    return DispatchQueue.main.sync {
      MainActor.assumeIsolated {
        SpotifyAuthPresentation.resolveAnchor()
      }
    }
    #else
    return ASPresentationAnchor()
    #endif
  }
}

#if os(iOS)
import UIKit
#endif
