Name: classification
Description: Determines a file's ownership, category, document type, and a confidence score from its extracted content. This is the first judgment call in the pipeline, filename generation, tagging, summarisation, and metadata enrichment all treat its output as input, not something they re-derive themselves.

Classification Skill

Input
text_excerpt: extracted text/content from the file (from Perceive), to judge ownership/category/type from
filename: original filename, for extra context when text_excerpt is thin
existing_categories: the categories already in use elsewhere in the graph, to prevent category sprawl
person_name: the archive owner's name, from config, never inferred from the file itself
confidence_threshold: not decided here, downstream (Metadata Enrichment) compares this skill's confidence score against it, this skill only ever outputs the raw score

Step 1: Determine ownership
Decide "own" or "other" based on what text_excerpt actually indicates: does this file belong to person_name (their resume, their essay, their own submitted assignment) or is it someone else's material (a professor's slides, a club's shared flyer, another person's document)?
Only two values are valid: own, other. If genuinely ambiguous, pick the more likely one and let the confidence score reflect the uncertainty, don't invent a third state.

Step 2: Determine category
Try to reuse an existing category from existing_categories first, the same reuse-over-sprawl principle Tagging applies to tags applies here to categories.
Only introduce a new category when the file's structural bucket genuinely isn't covered by anything in existing_categories, not merely because it's a more specific fit.
Category is structural (which bucket the file belongs in, e.g. a course code, Personal, Club, Internship), not topical, don't blend in subject matter here, that's what Content Summarisation and Tagging are for.

Step 3: Determine doc_type
A short, plain label for what kind of document this is (Essay, Slides, Notes, Assignment, Receipt, Reading, etc.), independent of category.
Reuse the closest existing doc_type convention rather than minting a new one for small variations (e.g. don't create "Lecture Slides" if "Slides" already covers it).

Step 4: Assign a confidence score
Score 0-1 reflecting how certain this classification actually is, based on how clear text_excerpt was, not on how confident the phrasing of the output sounds.
Thin, garbled, or empty text_excerpt (e.g. a scanned image with no OCR text) should produce a low score, not a guessed high one padded out from filename alone.
Don't inflate the score to avoid a file landing in review, an honest low score is what routes a genuinely ambiguous file to human review instead of silently mis-filing it.

Rules
Ownership, category, and doc_type are structural/administrative judgments, they answer "where does this file belong and what kind of thing is it," not "what is it about," that distinction is what separates this skill from Content Summarisation and Tagging.
Prefer reusing an existing category or doc_type over precision, exactly as Tagging prefers reusing an existing tag, a slightly-broader existing category beats a slightly-more-accurate new one.
Never derive category or doc_type from person_name or filename alone when text_excerpt is available and readable, content is the primary evidence.
The confidence score is this skill's own honest self-assessment, it is not adjusted or overridden by any downstream skill, Metadata Enrichment only compares it against confidence_threshold, it doesn't recompute it.
