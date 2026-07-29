# Spec 03 — AI selection & deduplication (LLM #1)

## Goal
From the ≤60 normalized items, the LLM selects the ~10 most relevant, deduplicated links.

## Design
- An **Aggregate** node ("Bundle items") first bundles the ≤60 items into a single item —
  otherwise the LLM chain would run once *per item* (60 Gemini calls instead of 1).
- Node: **Basic LLM Chain** ("Select links") + **Google Gemini Chat Model**
  (`models/gemini-flash-latest`, temperature 0.2). The `-latest` alias is deliberate:
  pinned versions like `gemini-2.5-flash` get retired for new API keys (returns 404),
  the alias always resolves to the current Flash model.
- Input: the full normalized list as JSON in the prompt.
- Prompt requirements:
  - a stated editorial line (e.g. "software engineering, AI/LLM tooling, DevOps — for a French consulting engineer")
  - deduplicate near-identical stories (same event covered by several sources → keep the best single link)
  - return **only** a JSON array of the selected items' `url` values, max 10
- A **Code** node ("Filter selected") then filters the original items by the returned
  URLs — the LLM selects, it never rewrites item data. It throws (fails the run) on
  non-JSON output, non-array output, or any URL absent from the input list.

## Acceptance criteria
- [x] Output is ≤10 items, all present verbatim in the input list — verified via `n8n execute`: 60 in → 10 out, all URLs verbatim, no duplicates
- [ ] Feeding the same story twice from two sources yields only one of them — enforced by the prompt; not deterministically testable (no forced duplicate in live feeds during verification)
- [x] Non-JSON / malformed model output makes the node fail visibly (no silent empty digest) — "Filter selected" throws on non-JSON, non-array, hallucinated URL, or empty selection
