import SwiftUI

typealias IOSPalette = KLTColor

enum IOSFont {
    static func display(_ size: CGFloat = 20) -> Font { .plexSans(size, weight: .bold) }
    static func body(_ size: CGFloat = 14) -> Font { .plexSans(size) }
    static func label(_ size: CGFloat = 11) -> Font { .plexSans(size, weight: .semibold) }
    static func mono(_ size: CGFloat = 11) -> Font { .plexMono(size, weight: .semibold) }
}
