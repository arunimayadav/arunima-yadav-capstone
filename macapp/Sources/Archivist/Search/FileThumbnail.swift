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

/// An actual preview of the file's first page (PDF) or content (matching what
/// Finder/Quick Look show), not just a generic file-type glyph. Falls back to the
/// type glyph while the thumbnail is loading or if none could be generated (e.g.
/// the file has since moved or Quick Look has no generator for it).
///
/// A real thumbnail keeps the file's own natural aspect ratio (a wide slide stays
/// wide, a portrait document stays tall) rather than being force-cropped into a
/// fixed square — matching how Quick Look and Finder show previews — bounded only
/// by `maxWidth`/`maxHeight` so it still fits the card. The fallback glyph, which
/// isn't a real preview of anything, keeps the fixed square treatment since a
/// generic icon has no "natural shape" to preserve.
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
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: glyphName)
                    .font(.system(size: maxHeight * 0.4))
                    .foregroundStyle(glyphTint)
                    .frame(width: maxHeight, height: maxHeight)
                    .background(glyphTint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .task(id: path) {
            await loadThumbnail()
        }
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
