# Spec 02 — Fetch & normalize sources

## Goal
Collect today's items from 3–4 tech-watch sources into one normalized list.

## Design
- Use a **Manual Trigger** during development (the schedule comes in spec 07).
- One **RSS Read** node per source, running as parallel branches:
  - Hacker News frontpage: `https://hnrss.org/frontpage`
  - dev.to: `https://dev.to/feed`
  - InfoQ: `https://feed.infoq.com/`
  - (optional 4th of your choice — e.g. a French source like Journal du Hacker)
- **Merge** node (append mode) → **Code** node normalizing each item to:

```json
{ "title": "...", "url": "...", "source": "hn|devto|infoq", "publishedAt": "ISO-8601", "excerpt": "≤300 chars, plain text" }
```

- Normalization rules: strip HTML from excerpts, drop items missing a URL,
  drop items older than 48h, sort by `publishedAt` desc, cap at **60 items**
  (keeps the Claude prompt in spec 03 small and cheap).

## Acceptance criteria
- [ ] Manual execution outputs a single list of ≤60 normalized items from all sources
- [ ] Every item matches the shape above (no HTML in `excerpt`, valid ISO date)
- [ ] A dead feed URL fails only its own branch (set "Continue on error" on RSS nodes), the rest still flow
