# Spec 02 — Fetch & normalize sources

## Goal
Collect today's items from 5 tech-watch sources into one normalized list.

## Design
- Use a **Manual Trigger** during development (the schedule comes in spec 07).
- One **RSS Read** node per source, running as parallel branches (each followed by a
  Set node tagging `source`, then merged via a 5-input append Merge):

  | Source | Tag | Feed URL |
  |---|---|---|
  | Hacker News frontpage | `hn` | `https://hnrss.org/frontpage` |
  | dev.to | `devto` | `https://dev.to/feed` |
  | Journal du Hacker | `jdh` | `https://www.journalduhacker.net/rss` |
  | Next | `nxt` | `https://next.ink/feed/` |
  | Korben | `kbn` | `https://korben.info/feed/` |

  (InfoQ was originally planned but its feed returns HTTP 406 to n8n's RSS
  node — user-agent filtering — so it was swapped out)
- **Merge** node (append mode) → **Code** node normalizing each item to:

```json
{ "title": "...", "url": "...", "source": "hn|devto|jdh|nxt|kbn", "publishedAt": "ISO-8601", "excerpt": "≤300 chars, plain text" }
```

- Normalization rules: strip HTML from excerpts, drop items missing a URL,
  drop items older than 48h, sort by `publishedAt` desc, cap at **60 items**
  (keeps the LLM prompt in spec 03 small — well inside Gemini free-tier quotas).

## Acceptance criteria
- [x] Manual execution outputs a single list of ≤60 normalized items from all sources — verified via `n8n execute`: raw feeds gave 129 items (hn: 20, devto: 12, jdh: 25, nxt: 50, kbn: 22); after the 48h filter + cap, Normalize output 60 items with all 5 sources present (hn: 20, kbn: 13, nxt: 12, devto: 12, jdh: 3). Note: per-feed counts in the UI are *raw*; the spec's numbers are *post-Normalize*, and counts vary run to run with feed content.
- [x] Every item matches the shape above (no HTML in `excerpt`, valid ISO date) — 0 shape/age violations, sorted desc
- [x] A dead feed URL fails only its own branch (`onError: continueRegularOutput` on RSS nodes), the rest still flow — proven live by the InfoQ 406: its branch emitted an error item, Normalize dropped it, the other 32 items flowed through
