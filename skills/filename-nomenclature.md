Name: filename-nomenclature
Description: Generates a consistent filename for a downloaded file from its classification (ownership, category, document type), and resolves filename collisions against what's already in the destination folder. Does not detect true duplicates, that's a File Action responsibility, run earlier via a content hash.

Filename Nomenclature Skill

Input
is_image: whether the file is an image (jpg/jpeg/png/heic/etc.), determines Case 1 vs Case 2/3
ownership: "own" or "other" (from Classification), determines Case 2 vs Case 3 for non-images
category: course code or other category (from Classification)
doc_type: short document type (from Classification), useful context when deriving a title, not part of the filename pattern itself
title_source: extracted text excerpt and/or original filename, to derive a clean title or image description from
file_date: the file's actual date (e.g. EXIF capture date, document date) if known, for Case 1 only
extension: original file extension, preserved as-is
person_name: the archive owner's name, from config, never inferred
existing_filenames: filenames already present in the destination folder, for collision checking

Step 1: Determine which case applies
If is_image is true, apply Case 1, image naming, regardless of ownership.
If is_image is false, apply Case 2 or Case 3 based on ownership: "other" is Case 2, "own" is Case 3.

Step 2: Apply the matching naming pattern

CASE 1 — Images:
<WhatItIs>_<dd-mm-yyyy>.<extension>
<WhatItIs> is a short description of what the image is actually about, derived from its content (e.g. receipt, screenshot-login-error, whiteboard-notes), not a generic label like "image" or "photo".
Date is file_date if known, otherwise today's date.
Example: receipt_19-09-2026.jpg

CASE 2 — Files NOT owned by the user (someone else's material):
<Category>_<Title>.<extension>
Category is the classified category (course code, "Personal", etc.). Title is a short, clean version of the file's actual subject, derived from title_source.
Example: TUI320_PrototypingLecture.pptx

CASE 3 — Files owned by the user (their own work):
<Category>_<Title>_<PersonFullName>.<extension>
Same Category and Title as Case 2, with the person's full name (from config, never inferred) appended at the end.
Example: TUI320_MidtermEssay_Arunima.docx

Step 3: Resolve filename collisions
This is the only duplicate-related logic this skill owns. True duplicate detection (byte-identical re-download) happens earlier and elsewhere, see note below.
Generate the name from Step 2.
Check it against existing_filenames in the destination folder.
If there's no collision, return the name as-is.
If the generated name already exists (a different file, different content hash, that happens to classify to the same name), append -2, -3, etc. before the extension, incrementing until the name is unique:
Arunima_Resume.pdf
Arunima_Resume-2.pdf

Rules
<WhatItIs> (Case 1) and <Title> (Cases 2/3): short, plain, and derived from the file's actual content via title_source, not a restatement of category or doc_type.
<Category>: whatever category actually fits (course code, Personal, Club, Internship, etc.), as classified, Case 2/3 only.
<PersonFullName>: always from config, never inferred from the file itself, Case 3 only, and always last in the filename.
Case is decided purely by is_image and ownership, never mixed, an image owned by the user still follows Case 1, not Case 3.
Always preserve the original file extension.
Remove characters that are invalid or awkward in filenames (/ \ : * ? " < > |, leading/trailing whitespace).
