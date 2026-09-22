Name: review
Description: The manual-resolution path for anything Classification flagged as low-confidence (status = pending in the nodes table). On-demand, not automatic, the user runs `review` when they choose to, the watcher never triggers it.

Review Skill

Input
pending_nodes: every node with status = pending, oldest first (or whatever order the user has configured)
per-node display fields: original filename and location, ownership/category/doc_type/confidence from Classification, summary and proposed tags, the suggested filename from Filename Nomenclature, and the model's one-line reasoning for why it wasn't confident
user_action: accept, edit, or reject, chosen per file
edits: corrected field values, only present when user_action is edit (any of ownership, category, doc_type, tags, filename)
mode: the File Action mode currently set (filed or flat), decides which status a resolved file lands on

Step 1: Fetch the queue
Pull every node with status = pending, oldest first by default.
This step only reads the queue, it doesn't touch File Action, Relationship Builder, or any node field yet.

Step 2: Show one file at a time
For each pending file, display everything Classification, Content Summarisation, Tagging, and Filename Nomenclature already produced for it: original filename/location, suggested ownership/category/doc_type/confidence, generated summary, proposed tags, suggested filename, and the model's one-line reasoning for the low confidence.
Nothing is recomputed here, this step is a read-only presentation of what the pipeline already decided, so the user can judge it.

Step 3: Resolve per the user's chosen action

Accept: take the suggestion as-is. Proceeds through the exact same path as a high-confidence auto-filed item, File Action applies the suggested name/move per the current mode, verifies it, logs the move, and status flips to filed (mode = filed) or indexed (mode = flat).

Edit: the user corrects any field inline (wrong course, wrong doc type, a better tag, a different filename) before accepting. Corrected values overwrite the suggested ones on the node, not appended alongside them, then it proceeds through File Action exactly like Accept. If the edit introduces a new tag, it's inserted into tags immediately, following the same reuse-over-sprawl rule Tagging already applies, not a separate ad hoc path.

Reject: the file is left untouched on disk. status is set to rejected, not pending, so it stops resurfacing in the queue on future runs. The file stays indexed and searchable either way, rejecting only means "don't act on it," it never means "forget it exists," so nothing else about the node (summary, tags, category) is cleared.

Step 4: Re-run Relationship Builder for accepted or edited files
Anything resolved as accept or edit gets Relationship Builder re-run against it, since its category and/or tags may have just changed and the graph's same_category/same_tag/similar_content edges need to reflect the corrected metadata, not the original low-confidence guess.
Rejected files skip this step entirely, nothing about them changed, there's nothing for Relationship Builder to reconsider.

Rules
Review only ever runs on-demand, never wire it into the watcher's automatic pipeline, that's the entire reason pending exists as a separate status from indexed.
Step 1's queue only ever returns pending nodes, once a node is filed, indexed, or rejected it's out of scope for review until something else (e.g. a re-classification) puts it back to pending.
Reject is not delete and not undo, the file's location, summary, tags, and category are untouched, only status changes, and no File Action move ever happens for a rejected item.
An edit's corrected values become the node's new ground truth, don't keep the original low-confidence suggestion around once it's been overwritten.
File Action (rename/move/verify/log) only ever runs for accept or edit, never for reject.
Relationship Builder only ever re-runs for accept or edit, never for reject, see Step 4.
