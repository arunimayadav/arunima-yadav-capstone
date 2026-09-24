import Foundation

enum ProviderKind: String, CaseIterable, Codable, Identifiable {
    case ollama, openai, anthropic, groq, gemini
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama: return "Ollama (local)"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .groq: return "Groq"
        case .gemini: return "Gemini"
        }
    }

    var requiresAPIKey: Bool { self != .ollama }

    /// Groq and Anthropic don't expose an embeddings endpoint (as of this writing) —
    /// embedding calls always fall back to Ollama or an embedding-capable cloud provider.
    var supportsEmbeddings: Bool {
        switch self {
        case .ollama, .openai, .gemini: return true
        case .anthropic, .groq: return false
        }
    }
}

enum ProviderError: Error {
    case notConfigured
    case requestFailed(String)
    case badResponse
}

/// A single AI backend capable of the four calls the pipeline needs.
/// Implementations: Ollama (local, default/fallback) and OpenAI/Anthropic/Groq/Gemini
/// (cloud, keyed) — see plan.md section 6/9.
protocol AIProvider {
    var kind: ProviderKind { get }
    func understand(excerpt: String, filename: String) async throws -> FileUnderstanding
    func embed(text: String) async throws -> [Float]
    func interpretCommand(_ text: String) async throws -> ParsedCommand
}

/// Shared prompt-building so every provider asks the same question the same way.
///
/// skills/tagging.md is embedded verbatim here (read fresh off disk by
/// SkillLoader). It's now a closed 5-way classification (Finance/Academic/
/// Personal/Health/Extra), not an open-ended judgment call — the model no longer
/// needs (or sees) a growing "existing tags" vocabulary to reuse from, since there
/// is nothing left to reuse: the five category names ARE the entire tag
/// vocabulary, permanently. `FixedCategory` in the Core layer is the code-level
/// backstop if a model still drifts and returns something else anyway.
///
/// skills/filename-nomenclature.md stays deliberately NOT embedded: its Step 1/2
/// (pattern assembly, collision resolution) is deterministic and implemented
/// directly in FilenameNomenclature.swift against the real file, so the model
/// never needs to see that skill's own text — it only supplies the raw judgment
/// fields (ownership/docType/title) that feed into it. (Confirmed failure mode
/// from testing: embedding that skill's own worked example caused a local model
/// to echo the example's literal words as its answer for an unrelated file.)
enum PromptBuilder {
    static func understandingPrompt(excerpt: String, filename: String) -> String {
        """
        You are a file-organization assistant. Given a file's name and a text excerpt,
        return STRICT JSON only, no prose, matching this shape:
        {"ownership": "own" or "other", "category": "Finance" or "Academic" or "Personal" or "Health" or "Extra", "docType": string, "title": string, "summary": string, "confidence": number between 0 and 1, "reasoning": string}

        === Tagging skill (governs the "category" field — this is a closed choice
        among exactly five values, not an open-ended judgment call) ===
        \(SkillLoader.tagging)
        === end tagging skill ===

        Field definitions:
        - "ownership": "own" if this is the archive owner's own authored work
          (an essay, an assignment, personal writing); "other" if it's something
          they received or downloaded from someone else (a lecture deck, a reading,
          an invoice, a statement).
        - "category": exactly one of Finance, Academic, Personal, Health, Extra —
          spelled exactly like that, nothing else is valid. Use Extra whenever the
          file genuinely doesn't belong in the other four; that is correct, not a
          fallback to avoid.
        - "docType": a short document type (Essay, Notes, Slides, Reading, Assignment,
          Invoice, Statement, Receipt, etc.) — pick the closest fit to the excerpt below.
        - "title": a short, clean version of THIS file's actual subject (2-5 words, no
          punctuation), describing what the excerpt below is actually about.
        - "summary" is one or two plain-language sentences about what this file actually
          is, independent of category, describing only the excerpt below.
        - "confidence" reflects how sure you are about the category given the excerpt length/quality.

        Every field above must be grounded only in the filename and excerpt given below.

        Filename: \(filename)
        Excerpt:
        \(excerpt.prefix(4000))
        """
    }

    static func commandPrompt(_ text: String) -> String {
        """
        You are a file-organization assistant. The user gave this instruction about
        organizing files already indexed in their system:
        "\(text)"

        Return STRICT JSON only, no prose, matching this shape:
        {"destinationFolderName": string, "searchQuery": string}

        "destinationFolderName" is a short, filesystem-safe folder name capturing their intent.
        "searchQuery" is the plain-language topic to search their file index for (e.g. "bank statements").
        """
    }

    /// Best-effort JSON extraction: some models wrap JSON in prose or code fences.
    static func extractJSON(from raw: String) -> Data? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            text = String(text[start...end])
        }
        return text.data(using: .utf8)
    }
}

struct UnderstandingJSON: Decodable {
    var ownership: String
    var category: String
    var docType: String
    var title: String
    var summary: String
    var confidence: Double
    var reasoning: String
}

struct CommandJSON: Decodable {
    var destinationFolderName: String
    var searchQuery: String
}

extension AIProvider {
    func decodeUnderstanding(_ raw: String) throws -> FileUnderstanding {
        guard let data = PromptBuilder.extractJSON(from: raw) else { throw ProviderError.badResponse }
        let parsed = try JSONDecoder().decode(UnderstandingJSON.self, from: data)
        // Normalized here, once, regardless of which provider answered: category
        // is clamped to one of the five fixed values (falling back to Extra for
        // anything else), and IS the tag now — no separate open-ended tag field.
        let category = FixedCategory.from(parsed.category).rawValue
        return FileUnderstanding(ownership: parsed.ownership, category: category, docType: parsed.docType,
                                  title: parsed.title, summary: parsed.summary, tags: [category],
                                  confidence: parsed.confidence, reasoning: parsed.reasoning)
    }

    func decodeCommand(_ raw: String) throws -> ParsedCommand {
        guard let data = PromptBuilder.extractJSON(from: raw) else { throw ProviderError.badResponse }
        let parsed = try JSONDecoder().decode(CommandJSON.self, from: data)
        return ParsedCommand(destinationFolderName: parsed.destinationFolderName, searchQuery: parsed.searchQuery)
    }
}
