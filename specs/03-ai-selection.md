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
  - a stated editorial line as a **prioritized reader profile**: 1) frontend — Vue.js
    ecosystem first, JavaScript/TypeScript news in general; 2) a11y, browser/web-platform
    features, UI/UX; 3) security (vulnerabilities, incidents, advisories); 4) AI and its
    impact on software development; 5) fun projects and clever hacks; cloud/DevOps only
    when major. The prompt asks to balance across priorities when the day's items allow.
  - deduplicate near-identical stories (same event covered by several sources → keep the best single link)
  - return **only** a JSON array of the selected items' `id` values (integers), max 10
- **Why ids and not URLs:** in live testing, Gemini *translated a French word inside a
  URL slug* while "copying" it (`affirme` → `affirms`). URLs must never round-trip
  through an LLM. Normalize stamps each item with a numeric `id`; the LLM selects ids;
  identity fields (url, title, source) are rebuilt from the original items.
- A **Code** node ("Filter selected") then filters the original items by the returned
  ids. It throws (fails the run) on non-JSON output, non-integer-array output, or any
  id absent from the input list. It emits the selection as **one bundled item**
  (`{data: [...]}`) so the next LLM chain (spec 04) runs once for the batch.
- Deliberately **not** merged into the LLM step: having the model output "curated,
  already-structured items" would require it to echo title/url/source — the identity
  round-trip that produced the `affirme`→`affirms` URL mangling. The Structured Output
  Parser validates shape, not fidelity; only a deterministic join by id guarantees
  byte-identical identity fields.

## Acceptance criteria
- [x] Output is ≤10 items, all present verbatim in the input list — verified via `n8n execute`: 60 in → 10 out, no duplicates; items are originals by construction (id-based selection)
- [ ] Feeding the same story twice from two sources yields only one of them — enforced by the prompt; not deterministically testable (no forced duplicate in live feeds during verification)
- [x] Non-JSON / malformed model output makes the node fail visibly (no silent empty digest) — "Filter selected" throws on non-JSON, non-array, hallucinated URL, or empty selection
