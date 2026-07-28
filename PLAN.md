# Implementation Plan — n8n Daily Tech-Watch Workflow

Goal: a daily n8n workflow that curates tech-watch links with Claude, publishes an
HTML digest to GitHub Pages, and notifies Discord. Built spec-first with Claude Code;

## Target pipeline

```
Schedule Trigger (09:30 Europe/Paris)
  → [RSS/HTTP fetch × N sources]  (parallel branches)
  → Merge + normalize (Code node → {title, url, source, publishedAt, excerpt})
  → Claude #1: select & deduplicate the most relevant links
  → Claude #2: extract structured JSON per link (tags, category, tl;dr)
  → Claude #3: write a short editorial intro (content only, no HTML structure)
  → Code node: inject JSON + intro into the shared template (templates/digest.html)
  → GitHub node: commit docs/digests/YYYY-MM-DD.html + update docs/digests.json manifest
  → Discord: post the digest link + top picks
```

Homepage: `docs/index.html` is a **static page committed once** — it fetches
`docs/digests.json` client-side and lists every published digest (latest first).
The workflow never edits the homepage, only appends to the manifest.
```

## Key decisions (rationale in the specs)

| Topic | Decision |
|---|---|
| n8n hosting | Self-hosted via Docker Compose, data persisted in a volume ([spec 01](specs/01-environment.md)) |
| Sources | 3–4 RSS feeds to start (Hacker News frontpage, dev.to, InfoQ…) — RSS avoids scraping fragility |
| AI nodes | n8n **Anthropic Chat Model** credential; steps 2 uses a Structured Output Parser so JSON is schema-validated |
| Claude calls | 3 separate nodes (select / extract / intro) rather than one mega-prompt — each is testable in isolation |
| Digest rendering | **Shared template** `templates/digest.html` filled by a Code node — Claude produces content, never page structure, so every digest looks identical ([spec 05](specs/05-html-digest.md)) |
| Homepage | Static `docs/index.html` + `docs/digests.json` manifest appended by the workflow — no HTML surgery on the index ([spec 06](specs/06-publish-notify.md)) |
| Publishing | GitHub Pages serving the `docs/` folder of `main` — n8n's GitHub node just commits files, Pages does the rest |
| Discord | **Webhook to a private server/channel you own.** True DMs require a Discord bot + token; a private-channel webhook is 1 node and equivalent proof. (Bot option documented in [spec 06](specs/06-discord.md)) |
| Versioning | Export the workflow to `workflow/tech-watch.json` after every phase — the repo is the source of truth |

## Phases

Each phase = one Claude Code session driven by its spec. Done means the acceptance
criteria in the spec pass and the workflow JSON is re-exported and committed.

- **Phase 0 — Scaffolding** (this commit): specs, README, `docs/` placeholder, `.gitignore`.
- **Phase 1 — Environment** ([spec 01](specs/01-environment.md)): Docker Compose for n8n, timezone config, credentials created in the n8n UI (Anthropic API key, GitHub fine-grained PAT, Discord webhook).
- **Phase 2 — Fetch & merge** ([spec 02](specs/02-fetch-sources.md)): Manual trigger for dev + RSS branches + normalization Code node. Verify ~50–100 normalized items.
- **Phase 3 — AI selection** ([spec 03](specs/03-ai-selection.md)): Claude picks ≤10 relevant, deduplicated links.
- **Phase 4 — JSON extraction** ([spec 04](specs/04-ai-extraction.md)): structured output (schema-enforced) per selected link.
- **Phase 5 — HTML digest** ([spec 05](specs/05-html-digest.md)): Claude writes the editorial intro; a Code node renders the shared template with the JSON.
- **Phase 6 — Publish & notify** ([spec 06](specs/06-publish-notify.md)): GitHub commits (digest page + manifest) → Pages live, homepage lists it; Discord message with link.
- **Phase 7 — Schedule & proof** ([spec 07](specs/07-schedule-proof.md)): swap manual trigger for 09:30 schedule, one real end-to-end run, screenshot the green execution, export final JSON.

## Risks / gotchas to expect

- **Rate/size limits**: cap items sent to Claude (~top 60 by recency) to keep prompts cheap.
- **HTML injection**: digest is built from third-party titles — spec 5 requires escaping.
- **GitHub Pages delay**: publish can take ~1 min after commit; Discord message links the stable URL, no need to wait.
- **09:30 means timezone**: set `GENERIC_TIMEZONE=Europe/Paris` on the n8n container, otherwise the schedule runs in UTC.
