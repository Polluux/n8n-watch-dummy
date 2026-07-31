# Implementation Plan — n8n Daily Tech-Watch Workflow

Goal: a daily n8n workflow that curates tech-watch links with an LLM (Google Gemini, free tier), publishes the digest to GitHub Pages, and notifies Discord. Built spec-first with Claude Code.

## Target pipeline

```
Schedule Trigger (09:30 Europe/Paris)
  → Sources (config list {name, tag, url}) → loop: fetch RSS + tag each item
  → Normalize (Code node → {id, title, url, source, sourceName, publishedAt, excerpt})
  → Code + GitHub contents API: drop candidates already published in the last 7 days
  → LLM #1 (Gemini): select & deduplicate the most relevant links (by id)
  → LLM #2 (Gemini): extract structured JSON per link (category, tags, tl;dr)
  → LLM #3 (Gemini): write a short editorial intro (content only, no HTML structure)
  → Code node: assemble the day's digest as a JSON payload (data only, no markup)
  → GitHub contents API: commit docs/digests/YYYY-MM-DD.json + register the date in docs/digests.json
  → Discord: post the digest link + top picks
```

The site renders client-side: `docs/index.html` (homepage) lists digests from the `docs/digests.json` date index; `docs/digest.html?d=YYYY-MM-DD` (viewer) fetches the day's JSON and renders it through component-style functions. Both pages are static, committed once, never touched by the workflow — layout changes restyle **all** digests retroactively.

## Key decisions (rationale in the specs)

| Topic | Decision |
|---|---|
| n8n hosting | Self-hosted via Docker Compose, data persisted in a volume ([spec 01](specs/01-environment.md)) |
| Sources | A config-driven list of `{name, tag, url}` feeds in the workflow's "Sources" node, looped over (Split In Batches) — adding a source is a one-line edit; docs stay source-agnostic. RSS avoids scraping fragility |
| LLM provider | **Google Gemini free tier** (n8n Google Gemini Chat Model node, API key from Google AI Studio — no credit card). The provider is swappable: only the chat-model sub-node changes |
| AI nodes | Step 2 uses a Structured Output Parser so JSON is schema-validated |
| LLM calls | 3 separate nodes (select / extract / intro) rather than one mega-prompt — each is testable in isolation |
| Digest rendering | **Client-side**: the workflow publishes JSON data; the static viewer `docs/digest.html` renders any digest — the LLM produces content, never structure; layout edits restyle all digests retroactively ([spec 05](specs/05-html-digest.md)) |
| Homepage | Static `docs/index.html` + `docs/digests.json` as a **pure date index** (static hosting can't list a directory; all day data lives in the payloads) ([spec 06](specs/06-publish-notify.md)) |
| Publishing | GitHub Pages serving the `docs/` folder of `main` — n8n's GitHub node just commits files, Pages does the rest |
| Discord | **Webhook to a private server/channel you own.** True DMs require a Discord bot + token; a private-channel webhook is 1 node for the same result. (Bot option documented in [spec 06](specs/06-publish-notify.md)) |
| Versioning | Export the workflow to `workflow/tech-watch.json` after every phase — the repo is the source of truth |

## Phases

Each phase = one Claude Code session driven by its spec. Done means the acceptance criteria in the spec pass and the workflow JSON is re-exported and committed.

- **Phase 0 — Scaffolding**: specs, README, `docs/` placeholder, `.gitignore`.
- **Phase 1 — Environment** ([spec 01](specs/01-environment.md)): Docker Compose for n8n, timezone config, credentials created in the n8n UI (Google Gemini API key, GitHub fine-grained PAT, Discord webhook).
- **Phase 2 — Fetch & normalize** ([spec 02](specs/02-fetch-sources.md)): source loop (fetch + tag) + normalization Code node.
- **Phase 3 — AI selection** ([spec 03](specs/03-ai-selection.md)): links published in the last 7 days are excluded in code, then Gemini picks ≤10 relevant, deduplicated links.
- **Phase 4 — JSON extraction** ([spec 04](specs/04-ai-extraction.md)): structured output (schema-enforced) per selected link.
- **Phase 5 — Digest payload** ([spec 05](specs/05-html-digest.md)): Gemini writes the editorial intro; a Code node assembles the day's JSON payload — the phase's deliverable.
- **Phase 6 — Publish & notify** ([spec 06](specs/06-publish-notify.md)): GitHub commits (payload + date index) → Pages live, homepage lists it; Discord message with link.
- **Phase 7 — Schedule** ([spec 07](specs/07-schedule.md)): swap the manual trigger for the 09:30 schedule, activate, verify a real scheduled end-to-end run.

## Operational notes

- **Rate/size limits**: items sent to the LLM are capped (top 60 by recency) — small prompts, well inside the Gemini free-tier quotas.
- **Untrusted input**: feed data reaches the DOM via `textContent` only, and hrefs are http(s)-only (spec 05).
- **GitHub Pages delay**: publish can take ~1 min after commit; the Discord message links the stable URL.
- **Timezone**: `GENERIC_TIMEZONE=Europe/Paris` on the n8n container — the 09:30 schedule is local time.
