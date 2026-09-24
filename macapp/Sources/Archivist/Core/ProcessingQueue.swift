import Foundation

/// Processes watched files strictly one at a time, FIFO.
///
/// Without this, each detected file would spawn its own independent Task, and two
/// files landing within the same few minutes (very plausible: the AI call alone
/// takes 1-3+ minutes with local Ollama) could both be mid-flight at once —
/// hammering local Ollama with concurrent requests it has to serialize internally
/// anyway, and racing on the content-hash insert if they happen to be
/// byte-identical. Serializing here keeps that simple and predictable: one file
/// fully completes (including its DB insert) before the next one starts.
actor ProcessingQueue {
    private let pipeline: Pipeline
    private var pending: [URL] = []
    private var isDraining = false

    init(pipeline: Pipeline) {
        self.pipeline = pipeline
    }

    func enqueue(_ url: URL) {
        pending.append(url)
        guard !isDraining else { return }
        isDraining = true
        Task { await drain() }
    }

    private func drain() async {
        while !pending.isEmpty {
            let next = pending.removeFirst()
            print("[Archivist][ProcessingQueue] starting \(next.lastPathComponent) (\(pending.count) more queued)")
            let node = await pipeline.process(fileAt: next)
            if let node {
                print("[Archivist][ProcessingQueue] finished \(next.lastPathComponent) -> " +
                      "status=\(node.status.rawValue) category=\(node.category) confidence=\(node.confidence)")
            } else {
                print("[Archivist][ProcessingQueue] \(next.lastPathComponent) produced no node " +
                      "(pre-existing file, duplicate, empty extraction, or unsupported type — see Pipeline logs above)")
            }
        }
        isDraining = false
    }
}
