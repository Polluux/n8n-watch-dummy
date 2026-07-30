# n8n-watch-dummy

Daily tech-watch digest built with **n8n + Google Gemini** (free tier), published to GitHub Pages, announced on Discord. A hands-on n8n learning project, developed spec-first with Claude Code. The LLM provider is swappable — only the chat-model sub-node changes.

**Live digest:** https://polluux.github.io/n8n-watch-dummy/

## How it works

Every day at 09:30 (Europe/Paris), n8n fetches several RSS tech sources, asks Gemini to select and deduplicate the most relevant links, extract structured JSON, and write an editorial intro. The workflow publishes the digest as **JSON data** in `docs/digests/` and registers its date in the index; the site renders everything client-side (`digest.html` viewer, `index.html` homepage — both static, committed once), and the day's selection is announced on Discord. Layout changes restyle all digests, past and future.

See [PLAN.md](PLAN.md) for the full pipeline and [specs/](specs/) for the per-phase specifications with acceptance criteria.

## Repository layout

- `PLAN.md` — implementation plan and design decisions
- `specs/` — one spec per phase (spec-driven development with Claude Code)
- `docs/` — GitHub Pages root: `index.html` (homepage), `digest.html` (digest viewer), `digests.json` (pure date index maintained by the workflow), `digests/` (one JSON payload per day)
- `workflow/` — the n8n workflow JSON (source of truth in git; n8n's own copy lives in its Docker volume)
- `scripts/export-workflow.sh` — sync UI edits back to the repo (run after editing in n8n; there is **no automatic sync** between the n8n database and this file)

## Running it

```bash
docker compose up -d   # n8n at http://localhost:5678
```

Credentials (Google Gemini API key, GitHub PAT, Discord webhook) are created in the n8n UI — see [specs/01-environment.md](specs/01-environment.md). Nothing secret lives in this repo.
