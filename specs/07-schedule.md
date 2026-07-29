# Spec 07 — Schedule, end-to-end run

## Goal
The workflow runs daily at 09:30 local time.

## Design
- Replace the Manual Trigger with a **Schedule Trigger**: cron `30 9 * * *`
  (Europe/Paris via the container's `GENERIC_TIMEZONE` — verify in the node's
  "next execution" preview).
- Activate the workflow (toggle in the n8n UI). Note: with local Docker, the machine
  must be on at 09:30 — acceptable for a demo project.
- Keep the Manual Trigger's dev-friendliness: you can still "Execute workflow" manually.

## Acceptance criteria
- [ ] Scheduled execution appears in n8n's Executions list at 09:30 the next day
- [ ] Digest + Discord message produced without manual action
