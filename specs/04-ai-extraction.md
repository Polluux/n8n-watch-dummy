# Spec 04 — Structured JSON extraction (LLM #2)

## Goal
Enrich each selected link into a structured record for the digest.

## Design
- "Filter selected" (spec 03) emits its result as a single bundled item (`{data: [...]}`), so the chain here runs once for the batch — one Gemini call, not one per item.
- **Basic LLM Chain** ("Extract data") + Google Gemini Chat Model (shared "Gemini Flash" sub-node) + **Structured Output Parser** ("Structured JSON") so the schema is enforced by n8n, not by prompt hope.
- **The LLM only produces judgment fields** — the record it returns per item is:

```json
{ "id": 0, "category": "ai | dev | devops | security | other", "tags": ["1-4 short keywords"], "tldr": "1-2 sentences, French" }
```

- A **Code** node ("Validate extraction") joins the records back to the original items by `id` and re-checks everything (count, ids, category enum, tag count, non-empty tldr), then emits the merged final records `{title, url, source, sourceName, publishedAt, category, tags, tldr}`.
- **Identity fields (title/url/source) never pass through the LLM** (same rule as spec 03): records are joined back to the originals by `id`, so URLs cannot be altered by construction.
- `tldr` is written from title + excerpt only — the workflow does not fetch article bodies (keep the dummy simple).

## Acceptance criteria
- [x] Output validates against the schema for all items (parser + validator errors surface as node failures) — verified via `n8n execute`: 10/10 records, 0 violations
- [x] `url` values are byte-identical to spec 03's output — by construction (urls never round-trip through the LLM)
- [x] `tldr` is in French and non-empty for every item — verified on live run (10/10 French summaries)
