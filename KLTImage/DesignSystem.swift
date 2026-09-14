import CoreText
import SwiftUI

enum KLTColor {
    static let inkStrong = Color(hex: 0x142A36)
    static let ink = Color(hex: 0x304854)
    static let inkMuted = Color(hex: 0x667B84)
    static let navy = Color(hex: 0x193A4A)
    static let accent = Color(hex: 0x007F92)
    static let accentPressed = Color(hex: 0x006C7D)
    static let accentSoft = Color(hex: 0xD9F0F3)
    static let surface = Color(hex: 0xF7F9F9)
    static let surfaceRaised = Color(hex: 0xFFFFFF)
    static let surfaceTint = Color(hex: 0xEDF3F4)
    static let canvas = Color(hex: 0xDBE3E5)
    static let divider = Color(hex: 0x9FB1B8)
    static let line = Color(hex: 0xC9D4D8)
    static let success = Color(hex: 0x18745F)
    static let warning = Color(hex: 0xA35F15)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension Font {
    static func plexSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        if weight == .bold {
            name = "IBMPlexSans-Bold"
        } else if weight == .semibold {
            name = "IBMPlexSans-SemiBold"
        } else {
            name = "IBMPlexSans-Regular"
        }
        return .custom(name, size: size, relativeTo: size >= 18 ? .title3 : (size >= 12 ? .body : .caption))
    }

    static func plexMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(
            weight == .semibold ? "IBMPlexMono-SemiBold" : "IBMPlexMono-Regular",
            size: size,
            relativeTo: size >= 12 ? .body : .caption
        )
    }
}

enum FontCatalog {
    static func registerBundledFonts() {
        guard let resources = Bundle.main.resourceURL else { return }
        guard let enumerator = FileManager.default.enumerator(
            at: resources,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for case let url as URL in enumerator where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.plexSans(12, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.white : KLTColor.inkMuted)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor(configuration: configuration))
            )
            .shadow(color: KLTColor.accent.opacity(isEnabled ? 0.18 : 0), radius: 6, y: 3)
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        guard isEnabled else { return KLTColor.surfaceTint }
        return configuration.isPressed ? KLTColor.accentPressed : KLTColor.accent
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.plexSans(12, weight: .semibold))
            .foregroundStyle(isEnabled ? KLTColor.inkStrong : KLTColor.inkMuted)
            .padding(.horizontal, 11)
            .frame(minHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? KLTColor.surfaceTint : KLTColor.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(KLTColor.divider.opacity(isEnabled ? 1 : 0.5), lineWidth: 1)
            )
    }
}
