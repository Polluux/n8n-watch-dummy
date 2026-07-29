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
- [x] Scheduled execution appears in n8n's Executions list — verified live: the Schedule Trigger fired on its cron tick and the execution ran unattended (publish commit landed 9s after trigger time). Verified with a temporary near-term cron; the mechanism is identical for the production `30 9 * * *`, which is now active (confirmed in the DB).
- [x] Digest + Discord message produced without manual action — verified with a temporary near-term cron: the scheduler fired at its tick and the full pipeline ran hands-free (publish commit `709a61c` landed 9 seconds after trigger time, Discord notified)
