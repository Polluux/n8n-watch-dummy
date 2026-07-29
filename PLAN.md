# Implementation Plan — n8n Daily Tech-Watch Workflow

Goal: a daily n8n workflow that curates tech-watch links with an LLM (Google Gemini,
free tier), publishes an HTML digest to GitHub Pages, and notifies Discord. Built
spec-first with Claude Code;

## Target pipeline

```
Schedule Trigger (09:30 Europe/Paris)
  → [RSS/HTTP fetch × N sources]  (parallel branches)
  → Merge + normalize (Code node → {title, url, source, publishedAt, excerpt})
  → LLM #1 (Gemini): select & deduplicate the most relevant links
  → LLM #2 (Gemini): extract structured JSON per link (tags, category, tl;dr)
  → LLM #3 (Gemini): write a short editorial intro (content only, no HTML structure)
  → Code node: assemble the day's digest as a JSON payload (data only, no markup)
  → GitHub node: commit docs/digests/YYYY-MM-DD.json + update docs/digests.json manifest
  → Discord: post the digest link + top picks
```

The site renders client-side: `docs/index.html` (homepage) lists digests from the
`docs/digests.json` manifest; `docs/digest.html?d=YYYY-MM-DD` (viewer) fetches the
day's JSON and renders it through component-style functions. Both pages are static,
committed once, never touched by the workflow — layout changes restyle **all**
digests retroactively.
```

## Key decisions (rationale in the specs)

| Topic | Decision |
|---|---|
| n8n hosting | Self-hosted via Docker Compose, data persisted in a volume ([spec 01](specs/01-environment.md)) |
| Sources | A configurable set of RSS feeds — the canonical list lives in the workflow's RSS Read nodes ([workflow/tech-watch.json](workflow/tech-watch.json)), docs stay source-agnostic. RSS avoids scraping fragility |
| LLM provider | **Google Gemini free tier** (n8n Google Gemini Chat Model node, API key from Google AI Studio — no credit card). The provider is swappable: only the chat-model sub-node changes |
| AI nodes | Step 2 uses a Structured Output Parser so JSON is schema-validated |
| LLM calls | 3 separate nodes (select / extract / intro) rather than one mega-prompt — each is testable in isolation |
| Digest rendering | **Client-side**: the workflow publishes JSON data; the static viewer `docs/digest.html` renders any digest — the LLM produces content, never structure; layout edits restyle all digests retroactively ([spec 05](specs/05-html-digest.md)). Supersedes an earlier design that fetched an HTML template from raw GitHub at run time |
| Homepage | Static `docs/index.html` + `docs/digests.json` as a **pure date index** (static hosting can't list a directory; all day data lives in the payloads) ([spec 06](specs/06-publish-notify.md)) |
| Publishing | GitHub Pages serving the `docs/` folder of `main` — n8n's GitHub node just commits files, Pages does the rest |
| Discord | **Webhook to a private server/channel you own.** True DMs require a Discord bot + token; a private-channel webhook is 1 node and equivalent proof. (Bot option documented in [spec 06](specs/06-discord.md)) |
| Versioning | Export the workflow to `workflow/tech-watch.json` after every phase — the repo is the source of truth |

## Phases

Each phase = one Claude Code session driven by its spec. Done means the acceptance
criteria in the spec pass and the workflow JSON is re-exported and committed.

- **Phase 0 — Scaffolding** (this commit): specs, README, `docs/` placeholder, `.gitignore`.
- **Phase 1 — Environment** ([spec 01](specs/01-environment.md)): Docker Compose for n8n, timezone config, credentials created in the n8n UI (Google Gemini API key, GitHub fine-grained PAT, Discord webhook).
- **Phase 2 — Fetch & merge** ([spec 02](specs/02-fetch-sources.md)): Manual trigger for dev + RSS branches + normalization Code node. Verify ~50–100 normalized items.
- **Phase 3 — AI selection** ([spec 03](specs/03-ai-selection.md)): Gemini picks ≤10 relevant, deduplicated links.
- **Phase 4 — JSON extraction** ([spec 04](specs/04-ai-extraction.md)): structured output (schema-enforced) per selected link.
- **Phase 5 — HTML digest** ([spec 05](specs/05-html-digest.md)): Gemini writes the editorial intro; a Code node renders the shared template with the JSON.
- **Phase 6 — Publish & notify** ([spec 06](specs/06-publish-notify.md)): GitHub commits (digest page + manifest) → Pages live, homepage lists it; Discord message with link.
- **Phase 7 — Schedule & proof** ([spec 07](specs/07-schedule-proof.md)): swap manual trigger for 09:30 schedule, one real end-to-end run, screenshot the green execution, export final JSON.

## Roadmap (post-phase-7 improvements)

- **Config-driven sources**: replace the per-source RSS + Tag branches with a single
  list of `{url, tag}` pairs the workflow loops over, so adding a source is a config
  edit rather than 2 nodes + a Merge input. Design wrinkle: the RSS Read node's output
  doesn't carry the input item's fields, so the tag must be re-attached inside the
  loop (Split In Batches around RSS Read, or HTTP Request + XML parsing).

## Risks / gotchas to expect

- **Rate/size limits**: cap items sent to the LLM (~top 60 by recency) — keeps prompts small and well inside the Gemini free-tier per-minute/per-day quotas.
- **HTML injection**: digests carry third-party titles — the viewer renders data via `textContent` only, never `innerHTML` (spec 05).
- **GitHub Pages delay**: publish can take ~1 min after commit; Discord message links the stable URL, no need to wait.
- **09:30 means timezone**: set `GENERIC_TIMEZONE=Europe/Paris` on the n8n container, otherwise the schedule runs in UTC.
