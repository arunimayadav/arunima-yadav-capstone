import Foundation

/// Applies skills/filename-nomenclature.md to a node and writes Finder tags —
/// the one shared implementation used both by Pipeline's automatic, high-
/// confidence flow and by Review's accept/edit resolution (skills/review.md
/// Step 3: "proceeds through File Action exactly like Accept"). Kept as a single
/// path rather than two copies so the rename/log/tag behavior can't silently
/// drift apart between the auto path and the reviewed path.
enum FileAction {
    /// Renames the file per skills/filename-nomenclature.md (resolving collisions
    /// against its destination folder), records the move, and writes Finder tags.
    /// Returns the up-to-date node, or nil if the source vanished mid-action or the
    /// rename itself failed (both already logged/cleaned up before returning).
    @discardableResult
    static func apply(node: Node, ownership: String, docType: String, title: String,
                       settings: SettingsStore, store: GraphStore, triggeredBy: String) -> Node? {
        let url = URL(fileURLWithPath: node.path)
        let name = url.lastPathComponent
        let directory = url.deletingLastPathComponent()

        // A file can vanish (deleted, moved away out-of-band) between being
        // indexed and being resolved here — the AI call and/or a human sitting on
        // the Review queue can both take a while. Same cleanup Pipeline always did.
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("[Archivist][FileAction] \(name): source file no longer exists — removing stale node")
            store.deleteNode(id: node.id)
            return nil
        }

        let siblings = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        var existingFilenames = Set(siblings)
        existingFilenames.remove(name) // renaming to our own current name isn't a "collision"

        // Case 1 (images) wants the file's actual date when it's known — EXIF
        // capture date isn't read separately anywhere yet, so this falls back to
        // the filesystem creation date, then to FilenameNomenclature's own
        // "today" default if even that isn't available.
        let fileDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate

        let input = FilenameNomenclature.Input(
            ownership: ownership, category: node.category, docType: docType,
            title: title, personName: settings.personName, fileExtension: url.pathExtension,
            fileDate: fileDate
        )
        let newName = FilenameNomenclature.filename(for: input, existingFilenames: existingFilenames)

        var finalNode = node
        var finalURL = url

        if newName != name {
            let newURL = directory.appendingPathComponent(newName)
            do {
                try FileManager.default.moveItem(at: url, to: newURL)
            } catch {
                if !FileManager.default.fileExists(atPath: url.path) {
                    print("[Archivist][FileAction] \(name): rename failed because the source vanished " +
                          "mid-move — removing this now-stale entry: \(error)")
                    store.deleteNode(id: node.id)
                } else {
                    print("[Archivist][FileAction] \(name): rename to \(newName) FAILED: \(error)")
                }
                return nil
            }
            store.recordMove(nodeId: node.id, srcPath: url.path, dstPath: newURL.path, triggeredBy: triggeredBy)
            guard let updated = store.node(id: node.id) else { return nil }
            finalURL = newURL
            finalNode = updated
            print("[Archivist][FileAction] \(name): renamed -> \(newName) (\(triggeredBy))")
        }

        if TagWriter.write(category: finalNode.category, to: finalURL) {
            print("[Archivist][FileAction] \(finalURL.lastPathComponent): wrote Finder tag " +
                  "\(finalNode.category)")
        }

        return finalNode
    }
}
