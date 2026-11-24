import Foundation
import CoreGraphics

// Keep the same crop budget as AttentionMediaLayout.kt. This uses the actual
// media ratio, so wide windows and portrait tablets fall back to contain.
enum AttentionMediaLayout {
    static func usesCover(media: CGSize, viewport: CGSize, full: Bool) -> Bool {
        guard full, media.width > 0, media.height > 0,
            viewport.width > 0, viewport.height > viewport.width
        else { return false }
        let mediaRatio = media.width / media.height
        let viewportRatio = viewport.width / viewport.height
        return min(mediaRatio / viewportRatio, viewportRatio / mediaRatio) >= 0.8
    }

    static func frame(media: CGSize, in bounds: CGRect, cover: Bool) -> CGRect {
        guard media.width > 0, media.height > 0, bounds.width > 0, bounds.height > 0
        else { return .zero }
        let widthScale = bounds.width / media.width
        let heightScale = bounds.height / media.height
        let scale = cover ? max(widthScale, heightScale) : min(widthScale, heightScale)
        let size = CGSize(width: media.width * scale, height: media.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
            width: size.width, height: size.height)
    }
}
