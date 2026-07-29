# Spec 02 — Fetch & normalize sources

## Goal
Collect today's items from the configured tech-watch sources into one normalized list.

## Design
- Use a **Manual Trigger** during development (the schedule comes in spec 07).
- **Sources are configuration, not spec.** The canonical list of feeds lives in the
  workflow itself ([workflow/tech-watch.json](../workflow/tech-watch.json), the RSS
  Read nodes) — this document deliberately doesn't duplicate it. Each source is a
  parallel branch: **RSS Read** node → **Set** node stamping a short `source` tag,
  merged via an N-input append Merge.
- Known quirk when adding sources: some feeds reject n8n's user-agent with HTTP 406
  (InfoQ does) — test a feed in the workflow before adopting it, not just with curl.
- Roadmap (see PLAN.md): replace the per-source branches with a config-driven list of
  `{url, tag}` pairs the workflow loops over. Wrinkle to solve: the RSS Read node's
  output doesn't carry the input item's fields, so the loop must re-attach the tag
  (e.g. Split In Batches around RSS Read, or HTTP Request + XML node instead) — that's
  why branches + Set nodes were the phase-2 choice.
- **Merge** node (append mode) → **Code** node normalizing each item to:

```json
{ "title": "...", "url": "...", "source": "<short tag from the source's Set node>", "publishedAt": "ISO-8601", "excerpt": "≤300 chars, plain text" }
```

- Normalization rules: strip HTML from excerpts, drop items missing a URL,
  drop items older than 48h, sort by `publishedAt` desc, cap at **60 items**
  (keeps the LLM prompt in spec 03 small — well inside Gemini free-tier quotas).

## Acceptance criteria
- [x] Manual execution outputs a single list of ≤60 normalized items from all configured sources — verified via `n8n execute` (5 sources at the time): 129 raw items → 60 post-Normalize, every source represented. Note: per-feed counts in the UI are *raw*; post-Normalize counts differ (48h filter + cap) and vary run to run with feed content.
- [x] Every item matches the shape above (no HTML in `excerpt`, valid ISO date) — 0 shape/age violations, sorted desc
- [x] A dead feed URL fails only its own branch (`onError: continueRegularOutput` on RSS nodes), the rest still flow — proven live by the InfoQ 406: its branch emitted an error item, Normalize dropped it, the other 32 items flowed through
