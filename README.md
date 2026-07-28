# n8n-watch-dummy

Daily tech-watch digest built with **n8n + Google Gemini** (free tier), published to
GitHub Pages, announced on Discord. A hands-on n8n learning project, developed
spec-first with Claude Code. The LLM provider is swappable — only the chat-model
sub-node changes.

**Live digest:** https://polluux.github.io/n8n-watch-dummy/

## How it works

Every day at 09:30 (Europe/Paris), n8n fetches several RSS tech sources, asks Gemini to
select and deduplicate the most relevant links, extract structured JSON, and write an
editorial intro. The digest page is rendered from a **shared template** (so every day
looks identical), committed to `docs/digests/` with a manifest entry, and announced on
Discord. The homepage lists every published digest from the manifest.

See [PLAN.md](PLAN.md) for the full pipeline and [specs/](specs/) for the per-phase
specifications with acceptance criteria.

## Repository layout

- `PLAN.md` — implementation plan and design decisions
- `specs/` — one spec per phase (spec-driven development with Claude Code)
- `docs/` — GitHub Pages root: `index.html` (static homepage listing all digests), `digests.json` (manifest appended by the workflow), `digests/` (one page per day)
- `templates/digest.html` — the shared digest template (single source of truth for layout)
- `workflow/` — exported n8n workflow JSON (added in phase 7)
- `assets/` — execution screenshots (added in phase 7)

## Running it

```bash
docker compose up -d   # n8n at http://localhost:5678
```

Credentials (Google Gemini API key, GitHub PAT, Discord webhook) are created in the n8n UI — see
[specs/01-environment.md](specs/01-environment.md). Nothing secret lives in this repo.
