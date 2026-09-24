Name: tagging
Description: Assigns a tag to a file from its extracted content. Reuses an existing tag whenever one reasonably fits, and only mints a new tag when nothing in the existing vocabulary matches. Keeps the tag vocabulary small, short, and non-overlapping over time, this is the sole guard against tag sprawl in the graph's emergent tags table.

Tagging Skill

Input
content_excerpt: extracted text/content from the file, to judge subject matter from
existing_tags: the full list of tag names already in the graph's tags table
category: category from Classification, if available, useful context but not a substitute for a tag
title_source: extracted text excerpt and/or original filename, for extra context when content_excerpt is thin

Step 0: Category is the strongest signal for tag reuse — check this first
Before judging semantic fit in Step 1: has any existing file with this SAME category already been assigned a tag?
If yes, that is very likely the right tag for this file too. Apply it directly, without re-deriving a fresh tag from this file's own content.
This is the concrete, checkable form of Step 1's "reasonably fits" test: two files sharing a category are, by definition, the same general subject as far as this vocabulary is concerned, so they should end up sharing a tag, not each getting their own close-but-different variant (both files classified as "Essay" get the exact same tag; not one "Essay" and the other "Essays" or "Course Essay" or "Writing" — those are the same thing wearing different names, which is exactly the sprawl this skill exists to prevent).
Only deviate from the category's established tag when the file's content is clearly about something more specific that you'd expect OTHER FUTURE files of this same category to also share — not a one-off distinction that only applies to this single file (that bar is Step 2's, for minting a new tag at all).

Step 1: Try to reuse an existing tag — but only a genuine fit
Read existing_tags first, before considering any new tag.
Ask: does the file's actual subject matter reasonably fit one of these already?
"Reasonably fits" means the tag would still make sense applied to other files on the same general subject, not only this one file.
If a tag fits, use it. Prefer reuse over precision, a slightly-broader existing tag beats a slightly-more-accurate new one.
If more than one existing tag could fit, choose the one that's already the closest semantic match rather than adding a second, overlapping tag.
Being present in existing_tags is not itself a reason to choose a tag. A confirmed real failure mode: grabbing an unrelated tag from the vocabulary just because it was offered as an option (e.g. tagging a finance document "User Experience" because that tag happened to exist from unrelated files) is worse than the tag sprawl this skill is trying to prevent. If nothing in existing_tags is a genuine, obvious fit, go to Step 2 instead of forcing one.

Step 2: Only create a new tag if nothing existing matches
A new tag is justified only when the file's subject is genuinely not covered by anything in existing_tags, not merely under-specified by it.
New tag names follow the same shape as good existing tags: short (1-3 words), broad enough to apply to a class of files, not to one file (Finance, not Q3-Bank-Statement; Lecture Notes, not DesignThinking-Week2-Notes).
Do not create a new tag that's just a narrower version of one that already exists (e.g. don't add "Bank Statements" if "Finance" exists and would fit).
Category names and tag names are allowed to overlap in spirit but serve different jobs, category is structural (where a file belongs), tag is topical (what it's about), don't default to copying category as the tag.

Rules
Exactly one tag per file, always. Earlier versions of this skill allowed a file to take more than one tag "if it genuinely spans two subjects" — that allowance is retired: in practice it became an escape hatch for hedging (stacking an extra, weakly-related existing tag alongside the real one instead of committing to the single best answer), which is precisely the sprawl this skill exists to prevent. Pick the one tag that best captures the file. If it truly spans two subjects, pick whichever one this specific file is more centrally about.
Tags are short, plain, and reusable, title case, no punctuation beyond spaces (Finance, Lecture Notes, Receipts, Club).
Never emit a tag that's a one-off, hyper-specific label built from this file's own title or date.
When in doubt between reusing a close-but-imperfect existing tag and minting a precise new one, reuse — but only when it's genuinely close. See Step 1's note: reuse driven by "it was on the list" rather than genuine fit is a bug, not a safe default.
Same category, same tag, every time. This is the primary correctness test for this skill: pull up every file with a given category and check whether they share a tag. If two files have the same category but different tags, that's a tagging bug, not an acceptable judgment-call difference — Step 0 exists specifically to prevent it, and the system enforces it in code as a hard rule, not a suggestion.
