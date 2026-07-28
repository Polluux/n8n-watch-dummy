# Spec 07 — Schedule, end-to-end run & proof

## Goal
The workflow runs daily at 09:30 local time; the repo contains the proof.

## Design
- Replace the Manual Trigger with a **Schedule Trigger**: cron `30 9 * * *`
  (Europe/Paris via the container's `GENERIC_TIMEZONE` — verify in the node's
  "next execution" preview).
- Activate the workflow (toggle in the n8n UI). Note: with local Docker, the machine
  must be on at 09:30 — acceptable for a demo project.
- Keep the Manual Trigger's dev-friendliness: you can still "Execute workflow" manually.

## Proof artifacts (committed to the repo)
- `workflow/tech-watch.json` — final export (n8n: workflow menu → Download).
  Check the export contains **no credential secrets** (n8n exports credential
  references only, but verify before committing).
- `assets/screenshot-canvas.png` — full canvas after a successful execution (green ticks on every node)
- `assets/screenshot-pages.png` — the live github.io digest
- `README.md` updated: architecture diagram, screenshot embeds, link to the live page

## Acceptance criteria
- [ ] Scheduled execution appears in n8n's Executions list at 09:30 the next day
- [ ] Digest + Discord message produced without manual action
- [ ] Repo contains workflow JSON + both screenshots; README renders them
