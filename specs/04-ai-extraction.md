# Spec 04 — Structured JSON extraction (Claude #2)

## Goal
Enrich each selected link into a structured record for the digest.

## Design
- Node: **Basic LLM Chain** + Anthropic Chat Model + **Structured Output Parser**
  so the schema is enforced by n8n, not by prompt hope.
- Runs once over the batch of selected items (single call, not per-item — cheaper).
- Output schema per item:

```json
{
  "title": "string",
  "url": "string (unchanged from input)",
  "source": "string",
  "category": "ai | dev | devops | security | other",
  "tags": ["string", "max 4"],
  "tldr": "string, 1–2 sentences, French"
}
```

- `tldr` is written from title + excerpt only — the workflow does not fetch article bodies (keep the dummy simple).

## Acceptance criteria
- [ ] Output validates against the schema for all items (parser errors surface as node failures)
- [ ] `url` values are byte-identical to spec 03's output
- [ ] `tldr` is in French and non-empty for every item
