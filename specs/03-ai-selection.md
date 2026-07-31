# Spec 03 — AI selection & deduplication (LLM #1)

## Goal
From the ≤60 normalized items, the LLM selects the ~10 most relevant links — none of them already published in the last 7 days.

## Design
- **Cross-day deduplication runs before selection, in code.** Normalize's 48h window is wider than the 24h run cadence, so every item is a candidate on two consecutive days; nothing in the LLM's view tells it what already shipped.
  - A **Code** node ("Recent dates") emits the 7 days **before** today (Europe/Paris), one item per date. Today is deliberately absent: a same-day re-run must be free to re-select the links it published that morning, or they would vanish from the digest entirely.
  - An **HTTP Request** node ("Get recent digests") fetches each day's payload from the GitHub contents API with the raw media type, so the JSON arrives already parsed. `onError: continue` — a 404 is simply a day without a digest (cold start, or a skipped run).
  - A **Code** node ("Drop published") removes every candidate whose URL already appeared in those payloads, then bundles the survivors into a single item (`{data, covered}`) so the LLM chain runs once for the batch (LLM chains execute once per input item — this replaces an Aggregate node).
    - URLs are compared in canonical form — lowercase host, no `www.`, no fragment, tracking params (`utm_*`, `fbclid`, `gclid`, …) stripped — because feeds re-emit the same article with varying query strings.
    - A missing day is skipped; any other fetch failure (credentials, rate limit, network) **throws**, so the run can never silently degrade into "nothing to exclude" and reprint yesterday's links.
    - `covered` carries the excluded headlines through to the prompt.
- **Basic LLM Chain** ("Select links") + **Google Gemini Chat Model** (`models/gemini-flash-latest`, temperature 0.2 — the rolling alias, since pinned model versions can be retired for new API keys).
- **The LLM selects by `id` only; identity fields never round-trip through it.** LLMs can subtly alter strings they "copy" — URLs included — so Normalize stamps each item with a numeric `id`, the LLM returns ids, and url/title/source are taken from the original items.
- Prompt requirements:
  - the editorial line as a **prioritized reader profile**: 1) frontend — Vue.js ecosystem first, JavaScript/TypeScript in general; 2) a11y, browser/web-platform features, UI/UX; 3) security; 4) AI and its impact on software development; 5) fun projects and clever hacks; cloud/DevOps only when major. Balance across priorities when the day's items allow.
  - deduplicate near-identical stories (same event from several sources → best single link)
  - the `covered` headlines under **"Already covered in recent digests"**, with an instruction never to select an item telling the same story as any of them — the model's contribution to dedup, catching another source's take on a story that already ran. The URL-level guarantee is the code's, not the model's.
  - return **only** a JSON array of the selected items' `id` values (integers), max 10
- A **Code** node ("Filter selected") maps the returned ids back to the original items — throwing on non-JSON output, non-integer-array output, or unknown ids — and emits the selection as one bundled item (`{data: [...]}`) for spec 04's chain.
  - Ids resolve against **"Drop published"**, not Normalize: an id excluded as already-published is therefore rejected as unknown rather than silently re-admitted.

## Acceptance criteria
- [x] Output is ≤10 items, all present verbatim in the input list — verified via `n8n execute`: 60 in → 10 out, no duplicates; items are originals by construction
- [x] No link published in the previous 7 days can reappear — verified via `n8n execute`: "Get recent digests" read 2 payloads (5 × 404 for days without one), 20 published URLs excluded 1 of the day's 60 candidates before selection; canonical matching collapses `?utm_*`, `www.` and `#fragment` variants of one link
- [x] A same-day re-run may re-select the links it already published — "Recent dates" spans the 7 days before today only; verified via `n8n execute` on a day whose payload was already committed (window `2026-07-30 … 2026-07-24`, current day absent)
- [x] A recent-digest fetch failure other than 404 fails the run visibly — "Drop published" throws rather than proceeding with an empty exclusion set
- [ ] Feeding the same story twice from two sources yields only one of them — enforced by the prompt; not deterministically testable against live feeds
- [x] Non-JSON / malformed model output fails the run visibly (no silent empty digest) — "Filter selected" throws on any malformed or unknown output
