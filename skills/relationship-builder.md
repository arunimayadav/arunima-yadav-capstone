Name: relationship-builder
Description: After a file's graph node is created and enriched with tags, category, and an embedding, finds related existing nodes and creates typed edges between them, this is what turns similarity search into an actual graph rather than a flat ranked list.

Relationship Builder Skill

Input
new_node: the just-enriched node (id, category, tags, embedding, filename/path), the source side of every edge this run creates
candidate_nodes: existing nodes already in the graph to compare new_node against (id, category, tags, embedding)
existing_edges: edges already present for new_node, if any, so this run updates rather than duplicates
similarity_threshold: minimum cosine similarity on embeddings for a similar_content edge to be worth creating

Step 1: Compare new_node against every candidate, one edge type at a time
Run all three checks below for each candidate_node. A single pair of nodes can end up with more than one edge type between them (e.g. same category and similar content), each edge type is judged independently, not as alternatives.

Step 2: same_category edge
If new_node.category exactly matches a candidate's category, that pair gets a same_category edge.
This is the coarsest, cheapest signal, exact match only, don't fuzzy-match category names here (that's Classification's job, not this skill's).

Step 3: same_tag edge
If new_node's tags and a candidate's tags share at least one tag in common, that pair gets a same_tag edge.
Weight it by overlap: more shared tags between the same two nodes means a stronger edge, not multiple edges, one same_tag edge per pair, weight reflects the overlap count.

Step 4: similar_content edge
Compute cosine similarity between new_node's embedding and a candidate's embedding.
If similarity >= similarity_threshold, create a similar_content edge with weight = the similarity score.
Below threshold, no edge, don't create a near-zero-weight edge just because two files are technically comparable, the threshold exists specifically to keep the graph from becoming fully connected noise.

Step 5: Write edges, keyed on (source, target, edge_type)
An edge is uniquely identified by its source node, target node, and edge_type, never write a second row for a pair that already has that edge_type.
If existing_edges already has this exact (source, target, edge_type), update its weight instead of inserting a duplicate.
Otherwise insert a new edge row.

Rules
Never create a self-edge, new_node is never compared against itself.
This skill only adds edges, it never deletes or prunes existing ones, that's a separate concern (e.g. handled when a node is deleted or re-classified).
Edge creation is symmetric in meaning (same_tag/same_category/similar_content all describe a mutual relationship) but only needs one row per pair per type, don't write both directions.
Don't invent new edge_type values, the three above (same_tag, same_category, similar_content) are the full set this skill produces.
similarity_threshold is a hard cutoff, not a suggestion, when in doubt about a borderline score, don't create the edge, a missing edge is recoverable (the next related file can still connect them), a graph cluttered with weak edges is not.
