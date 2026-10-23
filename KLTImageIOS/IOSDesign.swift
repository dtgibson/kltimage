import SwiftUI

typealias IOSPalette = KLTColor

enum IOSFont {
    static func display(_ size: CGFloat = 20) -> Font { .plexSans(size, weight: .bold) }
    static func body(_ size: CGFloat = 14) -> Font { .plexSans(size) }
    static func label(_ size: CGFloat = 11) -> Font { .plexSans(size, weight: .semibold) }
    static func mono(_ size: CGFloat = 11) -> Font { .plexMono(size, weight: .semibold) }
}

struct IOSActionButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IOSFont.label(14))
            .foregroundStyle(isEnabled ? (primary ? IOSPalette.surfaceRaised : IOSPalette.inkStrong) : IOSPalette.inkMuted)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .frame(minWidth: 44, minHeight: 44)
            .background(primary && isEnabled ? (configuration.isPressed ? IOSPalette.accentPressed : IOSPalette.accent) : IOSPalette.surfaceTint,
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
    }
}

struct IOSCanvasButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 44, minHeight: 44)
            .background(configuration.isPressed ? IOSPalette.surfaceTint : IOSPalette.surface)
            .contentShape(Rectangle())
    }
}
