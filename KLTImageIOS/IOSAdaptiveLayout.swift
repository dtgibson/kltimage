import SwiftUI

/// Local, safe-area-constrained sizes only. No device or orientation inference.
enum IOSWorkspaceLayout {
    static func showsInspector(size: CGSize, regularWidth: Bool, accessibilityText: Bool,
                               divisions: [CGRect] = []) -> Bool {
        guard regularWidth, !accessibilityText else { return false }
        for fold in divisions where fold.intersects(CGRect(origin: .zero, size: size)) {
            if fold.height > fold.width {
                return min(fold.minX, size.width - fold.maxX) >= 280 && size.height >= 440
            }
            return size.width >= 440 && min(fold.minY, size.height - fold.maxY) >= 280
        }
        return size.width >= 760 && size.height >= 440
    }

    /// Conservative fallback for custom content: use the largest unobstructed
    /// rectangle when a system container cannot divide its content usefully.
    static func usableRect(size: CGSize, avoiding regions: [CGRect]) -> CGRect {
        var available = CGRect(origin: .zero, size: size)
        for region in regions {
            let cut = available.intersection(region)
            guard !cut.isNull, cut.width > 0, cut.height > 0 else { continue }
            let candidates = [
                CGRect(x: available.minX, y: available.minY, width: max(0, cut.minX - available.minX), height: available.height),
                CGRect(x: cut.maxX, y: available.minY, width: max(0, available.maxX - cut.maxX), height: available.height),
                CGRect(x: available.minX, y: available.minY, width: available.width, height: max(0, cut.minY - available.minY)),
                CGRect(x: available.minX, y: cut.maxY, width: available.width, height: max(0, available.maxY - cut.maxY))
            ]
            available = candidates.max(by: { $0.width * $0.height < $1.width * $1.height }) ?? available
        }
        return available
    }
}

/// GeometryProxy already reports this container inside the system safe area.
/// Avoid interior occlusions too, including their system-supplied margins.
struct IOSReservedSafeContent<Content: View>: View {
    @ViewBuilder var content: (CGSize) -> Content
    var body: some View {
        GeometryReader { geometry in
            let rect = IOSWorkspaceLayout.usableRect(size: geometry.size, avoiding: reservedFrames(geometry))
            content(rect.size)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }

    private func reservedFrames(_ geometry: GeometryProxy) -> [CGRect] {
        if #available(iOS 27.1, *) {
            return (geometry.reservedRegions(kind: .occlusion) + geometry.reservedRegions(kind: .division)).map {
                $0.frame.inset(by: UIEdgeInsets(top: -$0.margins.top, left: -$0.margins.leading,
                                               bottom: -$0.margins.bottom, right: -$0.margins.trailing))
            }
        }
        return []
    }
}
