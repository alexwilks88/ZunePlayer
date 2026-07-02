import SwiftUI

enum ZuneTheme {
    static let background = Color.black
    static let foreground = Color.white

    static let menuFontSize: CGFloat = 52
}

extension Font {
    static var zuneMenu: Font {
        .custom("Segoe UI", size: ZuneTheme.menuFontSize)
    }
}
