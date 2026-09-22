import XCTest
@testable import Archivist

/// Exercises skills/review.md end to end against a throwaway GraphStore + temp
/// directory — never the real ~/Library/Application Support/Archivist database
/// or a real UserDefaults-backed setting, so running this can't disturb the
/// actual app's indexed files or configuration.
final class ReviewFlowTests: XCTestCase {
    private var tempDir: URL!
    private var store: GraphStore!
    private var settings: SettingsStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = GraphStore(path: tempDir.appendingPathComponent("test.sqlite3").path)
        settings = SettingsStore() // reads existing UserDefaults but this test never writes personName/provider
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeFile(named name: String, contents: String = "excerpt text") -> URL {
        let url = tempDir.appendingPathComponent(name)
        try! contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func insertPending(fileURL: URL, category: String, tags: [String],
                                confidence: Double = 0.4, hash: String) -> Node {
        let understanding = FileUnderstanding(
            ownership: "other", category: category, docType: "Slides", title: "PrototypingLecture",
            summary: "A lecture on prototyping methods.", tags: tags, confidence: confidence,
            reasoning: "Excerpt was short and ambiguous."
        )
        let id = store.insertNode(
            path: fileURL.path, filename: fileURL.lastPathComponent, understanding: understanding,
            providerUsed: "test", extractedText: "excerpt text", embedding: [],
            contentHash: hash, status: .pendingReview
        )
        return store.node(id: id)!
    }

    func testQueueFetchOnlyReturnsPending() {
        let fileURL = makeFile(named: "Untitled1.pdf")
        _ = insertPending(fileURL: fileURL, category: "TUI320", tags: ["Design"], hash: "h1")

        let queue = store.pendingReview()
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.status, .pendingReview)
    }

    func testAcceptAppliesFileActionAndIndexes() {
        let fileURL = makeFile(named: "Untitled2.pdf")
        let node = insertPending(fileURL: fileURL, category: "TUI320", tags: ["Design"], hash: "h2")

        let result = ReviewActions.accept(node: node, store: store, settings: settings)

        XCTAssertNotNil(result, "accept should return the resolved node")
        XCTAssertEqual(result?.status, .indexed, "accept must flip status to indexed, matching a high-confidence auto-filed item")
        XCTAssertEqual(result?.filename, "TUI320_PrototypingLecture.pdf", "ownership=other is Case 2: <Category>_<Title>, no doc type in the pattern")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("TUI320_PrototypingLecture.pdf").path),
            "the file itself must actually be renamed on disk, not just in the graph"
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "the original ugly filename should no longer exist")
        XCTAssertTrue(store.pendingReview().isEmpty, "resolved node must no longer appear in the review queue")
    }

    func testEditOverwritesFieldsBeforeAccepting() {
        let fileURL = makeFile(named: "Untitled3.pdf")
        let node = insertPending(fileURL: fileURL, category: "WrongCourse", tags: ["Design"], hash: "h3")

        let result = ReviewActions.edit(
            node: node, category: "TUI320", docType: "Notes", title: "CorrectedTitle",
            tags: ["Design", "Prototyping"], store: store, settings: settings
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.category, "TUI320", "edit's corrected category must overwrite the suggested one")
        XCTAssertEqual(Set(result?.tags ?? []), Set(["Design", "Prototyping"]), "edit's corrected tags must overwrite, not append to, the suggested set")
        XCTAssertEqual(result?.status, .indexed)
        XCTAssertEqual(result?.filename, "TUI320_CorrectedTitle.pdf", "the corrected fields, not the originals, must drive the filename (Case 2: no doc type in the pattern)")
    }

    func testAcceptOwnFileAppendsPersonName() {
        // Case 3: owned files append the person's name (from config), never
        // inferred from the file — distinct from Case 2's plain <Category>_<Title>.
        // settings.personName is backed by real UserDefaults.standard (not a
        // test-only store), so the previous value is saved and restored exactly,
        // never just deleted — this key may hold the user's actual configured name.
        let key = "archivist.personName"
        let previousValue = UserDefaults.standard.string(forKey: key)
        defer {
            if let previousValue {
                UserDefaults.standard.set(previousValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        settings.personName = "Arunima"

        let fileURL = makeFile(named: "Untitled6.docx")
        let understanding = FileUnderstanding(
            ownership: "own", category: "TUI320", docType: "Essay", title: "MidtermEssay",
            summary: "The user's own midterm essay.", tags: ["Design"], confidence: 0.4,
            reasoning: "Ambiguous course code in the excerpt."
        )
        let id = store.insertNode(
            path: fileURL.path, filename: fileURL.lastPathComponent, understanding: understanding,
            providerUsed: "test", extractedText: "excerpt", embedding: [], contentHash: "h6", status: .pendingReview
        )
        let node = store.node(id: id)!

        let result = ReviewActions.accept(node: node, store: store, settings: settings)
        XCTAssertEqual(result?.filename, "TUI320_MidtermEssay_Arunima.docx", "Case 3: <Category>_<Title>_<PersonFullName>")
    }

    func testAcceptImageUsesHyphenatedWhatItIsAndDate() {
        // Case 1: images always use <WhatItIs>_<dd-mm-yyyy>, regardless of
        // ownership — an image owned by the user still follows Case 1, not Case 3.
        let fileURL = makeFile(named: "IMG_0001.jpg")
        let understanding = FileUnderstanding(
            ownership: "own", category: "Personal", docType: "Photo", title: "Whiteboard Notes",
            summary: "A photo of a whiteboard.", tags: ["Notes"], confidence: 0.4,
            reasoning: "No extractable text from an image."
        )
        let id = store.insertNode(
            path: fileURL.path, filename: fileURL.lastPathComponent, understanding: understanding,
            providerUsed: "test", extractedText: "", embedding: [], contentHash: "h7", status: .pendingReview
        )
        let node = store.node(id: id)!

        let result = ReviewActions.accept(node: node, store: store, settings: settings)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.filename.hasPrefix("whiteboard-notes_"), "Case 1's <WhatItIs> is lowercase/hyphenated, not TitleCase")
        XCTAssertTrue(result!.filename.hasSuffix(".jpg"))
    }

    func testRejectLeavesFileUntouchedAndOutOfQueue() {
        let fileURL = makeFile(named: "Untitled4.pdf")
        let node = insertPending(fileURL: fileURL, category: "TUI320", tags: ["Design"], hash: "h4")

        ReviewActions.reject(node: node, store: store)

        let reloaded = store.node(id: node.id)
        XCTAssertEqual(reloaded?.status, .rejected)
        XCTAssertEqual(reloaded?.filename, node.filename, "reject must never rename or move the file")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "the original file must still exist, untouched, at its original path")
        XCTAssertTrue(store.pendingReview().isEmpty, "a rejected node must not resurface in the review queue")
        XCTAssertNotNil(reloaded, "reject must not delete the node — it stays indexed/searchable")
    }

    func testAcceptReRunsRelationshipBuilder() {
        // An existing, already-indexed node in the same category the pending
        // node is about to be accepted into.
        let existingURL = makeFile(named: "AlreadyIndexed.pdf")
        let existingUnderstanding = FileUnderstanding(
            ownership: "other", category: "TUI320", docType: "Slides", title: "Intro",
            summary: "An earlier lecture.", tags: ["Design"], confidence: 0.9, reasoning: ""
        )
        let existingId = store.insertNode(
            path: existingURL.path, filename: existingURL.lastPathComponent, understanding: existingUnderstanding,
            providerUsed: "test", extractedText: "excerpt", embedding: [], contentHash: "existing-hash", status: .indexed
        )

        let fileURL = makeFile(named: "Untitled5.pdf")
        let node = insertPending(fileURL: fileURL, category: "TUI320", tags: ["Design"], hash: "h5")

        guard let result = ReviewActions.accept(node: node, store: store, settings: settings) else {
            return XCTFail("accept should succeed")
        }

        let connected = store.connectedNodes(to: result.id)
        XCTAssertTrue(connected.contains { $0.id == existingId },
                      "Relationship Builder must re-run after accept, connecting the resolved node to the existing same-category/same-tag node")
    }
}
