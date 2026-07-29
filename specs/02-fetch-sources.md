# Spec 02 — Fetch & normalize sources

## Goal
Collect today's items from the configured tech-watch sources into one normalized list.

## Design
- Use a **Manual Trigger** during development (the schedule comes in spec 07).
- **Sources are configuration, not spec.** The canonical list lives in the workflow's
  **"Sources" Code node** as a `{name, tag, url}` array — this document deliberately
  doesn't duplicate it. Adding/removing/renaming a source is a one-line edit there.
- **Config-driven loop** (replaced the original per-source branches): Sources →
  **Loop sources** (Split In Batches, one source per iteration) → **Fetch RSS**
  (`url = {{ $json.url }}`, continue-on-error) → **Tag items** (Code: re-attaches the
  current source's `tag` and `name` to every fetched item) → back to the loop; the
  loop's *done* output feeds Normalize with all items combined.
  The re-attach step exists because the RSS Read node's output doesn't carry its
  input's fields — the loop context is the only place that still knows the source.
- Items carry both `source` (short tag, internal) and `sourceName` (display name,
  shown on the digest cards).
- Known quirk when adding sources: some feeds reject n8n's user-agent with HTTP 406
  (InfoQ does) — test a feed in the workflow before adopting it, not just with curl.
- **Merge** node (append mode) → **Code** node normalizing each item to:

```json
{ "title": "...", "url": "...", "source": "<short tag>", "sourceName": "<display name>", "publishedAt": "ISO-8601", "excerpt": "≤300 chars, plain text" }
```

- Normalization rules: strip HTML from excerpts, drop items missing a URL,
  drop items older than 48h, sort by `publishedAt` desc, cap at **60 items**
  (keeps the LLM prompt in spec 03 small — well inside Gemini free-tier quotas).

## Acceptance criteria
- [x] Manual execution outputs a single list of ≤60 normalized items from all configured sources — re-verified after the loop refactor: 5 loop iterations, 128 raw items → 60 post-Normalize, every source tagged with `source` + `sourceName`. Note: per-feed counts in the UI are *raw*; post-Normalize counts differ (48h filter + cap) and vary run to run with feed content.
- [x] Every item matches the shape above (no HTML in `excerpt`, valid ISO date) — 0 shape/age violations, sorted desc
- [x] A dead feed URL fails only its own iteration (`onError: continueRegularOutput` on Fetch RSS), the rest still flow — re-proven after the loop refactor by pointing one source at a 404: its iteration emitted an error item, the loop continued, Normalize output 60 items from the remaining sources
