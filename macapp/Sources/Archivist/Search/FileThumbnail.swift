import SwiftUI
import AppKit
import QuickLookThumbnailing

/// Caches generated thumbnails in memory so scrolling or re-rendering the same
/// result doesn't regenerate them — QLThumbnailGenerator is an out-of-process
/// round trip and shouldn't be repeated per file more than once per session.
private final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, NSImage>()

    func image(for path: String) -> NSImage? { cache.object(forKey: path as NSString) }
    func store(_ image: NSImage, for path: String) { cache.setObject(image, forKey: path as NSString) }
}

/// A page silhouette with a folded top-right corner ("dog-ear") — the classic
/// generic-document look, used instead of a plain rounded rectangle so a
/// thumbnail reads as "a page" at a glance. The fold is a fraction of whichever
/// dimension is smaller, so it scales sensibly whether the shape ends up wide
/// (a landscape slide) or tall (a portrait document).
private struct PageCornerShape: Shape {
    var cornerRadius: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        let fold = min(rect.width, rect.height) * 0.32
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addArc(center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addArc(center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                    radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// The small triangular flap in the cut corner, shaded to suggest it's folded
/// over onto the page — the detail that reads as "folded corner" rather than
/// just "rectangle with a corner missing."
private struct PageCornerFold: Shape {
    func path(in rect: CGRect) -> Path {
        let fold = min(rect.width, rect.height) * 0.32
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
        path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY + fold))
        path.closeSubpath()
        return path
    }
}

/// An actual preview of the file's first page (PDF) or content (matching what
/// Finder/Quick Look show), styled as a page with a folded top-right corner —
/// not just a flat clipped image. Falls back to the same page shape with a
/// centered type glyph while the thumbnail is loading or if none could be
/// generated (e.g. the file has since moved or Quick Look has no generator for it).
///
/// Keeps the file's own natural aspect ratio (a wide slide stays wide, a portrait
/// document stays tall) rather than being force-cropped into a fixed square —
/// bounded only by `maxWidth`/`maxHeight` so it still fits the card.
struct FileThumbnailView: View {
    let path: String
    let glyphName: String
    let glyphTint: Color
    var maxWidth: CGFloat = 56
    var maxHeight: CGFloat = 56

    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                // Exact fitted size, not `.frame(maxWidth:maxHeight:)` — that only
                // caps the box the image is *drawn within*, so for anything that
                // isn't already exactly square, the image itself renders smaller
                // than the box and the pageSurface background behind it fills the
                // leftover space as a visible plain-color margin. Sizing the frame
                // to the image's own fitted dimensions means there's no leftover
                // space for a margin to appear in — the container IS the image.
                let size = fittedSize(for: thumbnail.size)
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .background(ArchivistPalette.pageSurface)
                    .pageCornerStyle()
                    // Quick Look/Preview-style page shadow — only the real
                    // rendered thumbnail gets this; the fallback below doesn't,
                    // since a generic icon isn't "a page" the same way.
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
            } else {
                ZStack {
                    ArchivistPalette.pageSurface
                    Image(systemName: glyphName)
                        .font(.system(size: maxHeight * 0.36))
                        .foregroundStyle(glyphTint)
                }
                .frame(width: maxHeight, height: maxHeight)
                .pageCornerStyle()
            }
        }
        .task(id: path) {
            await loadThumbnail()
        }
    }

    /// The image's own size scaled down (never up) to fit within maxWidth/maxHeight
    /// while preserving aspect ratio — computed explicitly rather than left to
    /// `.frame(maxWidth:maxHeight:)`, which reports the full requested box as its
    /// size regardless of the image's actual proportions.
    private func fittedSize(for imageSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGSize(width: maxWidth, height: maxHeight)
        }
        let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height, 1)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    @MainActor
    private func loadThumbnail() async {
        if let cached = ThumbnailCache.shared.image(for: path) {
            thumbnail = cached
            return
        }
        guard FileManager.default.fileExists(atPath: path) else { return }

        let url = URL(fileURLWithPath: path)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        // Requesting at the larger of the two caps and letting SwiftUI's own
        // aspectRatio(.fit) constrain the final render — QLThumbnailGenerator
        // already returns an appropriately-proportioned image for the requested
        // box, this just avoids asking for a needlessly small render on the
        // dimension that isn't the limiting one for a given file's shape.
        let requestSize = max(maxWidth, maxHeight)
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: requestSize, height: requestSize),
            scale: scale,
            representationTypes: .thumbnail
        )

        let generated: NSImage? = await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.nsImage)
            }
        }

        if let generated {
            ThumbnailCache.shared.store(generated, for: path)
            thumbnail = generated
        }
    }
}

private extension View {
    /// Clips to the folded-corner page shape and draws the fold flap + a hairline
    /// border — shared by both the real-thumbnail and fallback-glyph cases so they
    /// read as the same visual language.
    func pageCornerStyle() -> some View {
        self
            .clipShape(PageCornerShape())
            .overlay(PageCornerFold().fill(Color.black.opacity(0.12)))
            .overlay(PageCornerShape().stroke(Color.black.opacity(0.1), lineWidth: 0.75))
    }
}
