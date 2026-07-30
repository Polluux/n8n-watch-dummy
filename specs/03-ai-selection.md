# Spec 03 — AI selection & deduplication (LLM #1)

## Goal
From the ≤60 normalized items, the LLM selects the ~10 most relevant, deduplicated links.

## Design
- An **Aggregate** node ("Bundle items") bundles the ≤60 items into a single item so the LLM chain runs once for the batch (LLM chains execute once per input item).
- **Basic LLM Chain** ("Select links") + **Google Gemini Chat Model** (`models/gemini-flash-latest`, temperature 0.2 — the rolling alias, since pinned model versions can be retired for new API keys).
- **The LLM selects by `id` only; identity fields never round-trip through it.** LLMs can subtly alter strings they "copy" — URLs included — so Normalize stamps each item with a numeric `id`, the LLM returns ids, and url/title/source are taken from the original items.
- Prompt requirements:
  - the editorial line as a **prioritized reader profile**: 1) frontend — Vue.js ecosystem first, JavaScript/TypeScript in general; 2) a11y, browser/web-platform features, UI/UX; 3) security; 4) AI and its impact on software development; 5) fun projects and clever hacks; cloud/DevOps only when major. Balance across priorities when the day's items allow.
  - deduplicate near-identical stories (same event from several sources → best single link)
  - return **only** a JSON array of the selected items' `id` values (integers), max 10
- A **Code** node ("Filter selected") maps the returned ids back to the original items — throwing on non-JSON output, non-integer-array output, or unknown ids — and emits the selection as one bundled item (`{data: [...]}`) for spec 04's chain.

## Acceptance criteria
- [x] Output is ≤10 items, all present verbatim in the input list — verified via `n8n execute`: 60 in → 10 out, no duplicates; items are originals by construction
- [ ] Feeding the same story twice from two sources yields only one of them — enforced by the prompt; not deterministically testable against live feeds
- [x] Non-JSON / malformed model output fails the run visibly (no silent empty digest) — "Filter selected" throws on any malformed or unknown output
