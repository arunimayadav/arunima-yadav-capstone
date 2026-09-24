Name: tagging
Description: Assigns a file's category from a fixed, closed list of exactly five values. The category IS the tag — there is no separate open-ended tagging decision anymore. Every file in a category always gets that category's one fixed color, so the tag vocabulary can never sprawl and colors never drift.

Tagging Skill

Input
content_excerpt: extracted text/content from the file, to judge subject matter from
title_source: extracted text excerpt and/or original filename, for extra context when content_excerpt is thin

The five allowed categories (exact spelling, nothing else is valid)
Finance — money: invoices, receipts, statements, budgets, payments, financial planning.
Academic — school/coursework: assignments, lecture notes, readings, essays, research, class projects.
Personal — the archive owner's own non-academic life: personal writing, journaling, personal projects, correspondence.
Health — anything medical or wellness-related: records, appointments, fitness, prescriptions, insurance for health.
Extra — everything else. This is not a last resort to avoid — it is the correct, designated answer whenever a file genuinely doesn't belong in the other four. Do not stretch a file into Finance/Academic/Personal/Health just to avoid using Extra.

Step 1: Pick exactly one of the five
Read the excerpt (and title_source if the excerpt is thin) and decide which of the five categories the file's actual subject matter belongs to.
This is a single closed-set classification, not an open-ended judgment call — there is no Step 2 for inventing a new category, and no "close enough" partial credit between two of the five. Pick the one best fit.
If genuinely unsure among two categories, prefer whichever a person would look for the file under later — that's the entire purpose of this classification.
If the content doesn't clearly belong to Finance, Academic, Personal, or Health, use Extra. That is the intended, correct outcome for that case, not a failure.

Rules
Exactly one category per file, always — this was already true before, but is now also the ONLY output this skill produces (there is no separate "tag" field to fill in anymore).
Never invent a sixth category, a variant spelling, or a more specific sub-category ("Coursework" instead of "Academic", "Bills" instead of "Finance"). Only the five exact names above are valid.
Same content, same category, every time — this is the correctness test for this skill, same as it always was, just simpler to check now: two files about the same kind of thing should get the exact same one of the five values, not two different-but-similar labels.
Category is applied as the file's Finder tag and gets that category's one fixed color (Finance/Academic/Personal/Health/Extra each map to a permanent, specific color — never computed per-file, so the same category always looks the same in Finder).
