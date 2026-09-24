Name: metadata-enrichment
Description: Assembles and writes the complete record for a processed file, location, tags, category, summary, confidence, status, and timestamps, onto its graph node. This full record is what gets returned on search, not just a filename.

Metadata Enrichment Skill

Input
path / filename: current location on disk and the original filename
classification_result: category, confidence, ownership, doc_type, from Classification
summary: plain-language summary, from Content Summarisation
tags: resolved tag list, from Tagging
embedding: content vector, from the active AIProvider
provider_used: which AIProvider backend produced this record
content_hash: SHA-256 dedup key
extracted_text: the truncated excerpt used for all upstream AI calls
confidence_threshold: the cutoff that decides indexed vs pending_review
existing_node: the node row already on disk, if this is a re-enrichment rather than a first write

Step 1: Assemble the record from upstream outputs, don't recompute them
Collect path, filename, category, summary, tags, confidence, provider_used, content_hash, and extracted_text as already produced by Classification, Content Summarisation, Tagging, and the embedding call.
This skill's job is assembly and writing, not judgment, if a field looks wrong (e.g. a suspiciously low confidence), write it as given rather than second-guessing or re-deriving it here, that's each upstream skill's own responsibility.

Step 2: Decide status from confidence
If confidence >= confidence_threshold, status = indexed.
If confidence < confidence_threshold, status = pending_review.
status = duplicate_skipped is never set by this skill, that value only comes from the dedup gate earlier in the pipeline, before this skill ever runs, don't overwrite it if the record already carries it.

Step 3: Stamp timestamps
created_at is set once, the first time this node is written, and never changes after that, even on later re-enrichment.
updated_at is set every time this skill writes the record, including re-enrichment of an existing node.
If existing_node is present, preserve its created_at rather than resetting it.

Step 4: Write the complete record onto the node
Write path, filename, category, summary, tags, confidence, status, provider_used, extracted_text, embedding, content_hash, created_at, and updated_at as one record, this is what a search result returns, not just a filename match.
If existing_node is present (re-enrichment, e.g. after a move or a re-classification), update the existing row in place rather than inserting a second node for the same file.
If existing_node is absent, insert a new node row.

Rules
Never write a partial record, every field this skill owns (see Step 4) gets set on every write, a blank tag list or missing summary silently degrades every future search result for that file.
This skill does not generate content, category, tags, summary, and embedding are inputs here, if one is missing, that's an upstream failure to surface, not something to guess at in this skill.
confidence is stored as the raw 0-1 score produced by Classification, don't round, bucket, or otherwise transform it beyond the threshold comparison in Step 2.
tags and category can change on re-enrichment (a file can be reclassified), when they do, the node is updated in place, old values aren't kept around as history.
path is kept current, if a file is moved by a later action (review approval, natural-language command), that update is this skill's job too, not a separate one, the node's path must always reflect where the file actually is.

Step 5: Surfacing the record in the UI
The complete record is still assembled and written in full on every call, per Steps 1-4, regardless of what the UI happens to show, this step only concerns what a user sees when they tap a search result card.
Tapping a card expands it in place to show path (as "Location"), created_at, and updated_at ("Last updated") plus a Reveal in Finder action, that's the whole expanded view.
category/tag is not repeated in the expanded view, it's already shown on the collapsed card.
status, confidence, doc_type, and ownership are not shown in the expanded view, a user reviewing search results has no use for them, they stay computed and stored on the node exactly as Steps 2-4 describe, they're just not display fields here.
