# Spec 01 — Environment & credentials

## Goal
A reproducible local n8n instance with persisted data and all credentials configured.

## Requirements
- `docker-compose.yml` at repo root running `n8nio/n8n:latest`:
  - port `5678:5678`
  - volume `n8n_data:/home/node/.n8n` (workflows/credentials survive restarts)
  - env: `GENERIC_TIMEZONE=Europe/Paris`, `TZ=Europe/Paris`
- Credentials created **in the n8n UI** (never committed to the repo):
  - **Google Gemini (PaLM) API** — API key from Google AI Studio (aistudio.google.com, free tier, no credit card). Used by the Google Gemini Chat Model nodes.
  - **GitHub** — fine-grained PAT scoped to this repo only, permission: Contents read/write
  - **Discord webhook URL** — from a private server you own: channel → Integrations → Webhooks
- GitHub Pages enabled on this repo: Settings → Pages → Deploy from branch → `main` / `docs/`

## Acceptance criteria
- [x] `docker compose up -d` → n8n UI reachable at http://localhost:5678
- [x] `docker compose down && up` keeps workflows/credentials
- [x] All three credentials pass n8n's built-in credential test
- [x] A placeholder `docs/index.html` is visible at `https://<user>.github.io/n8n-watch-dummy/`
