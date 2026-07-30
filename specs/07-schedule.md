# Spec 07 — Schedule, end-to-end run

## Goal
The workflow runs daily at 09:30 local time.

## Design
- Replace the Manual Trigger with a **Schedule Trigger**: cron `30 9 * * *` (Europe/Paris via the container's `GENERIC_TIMEZONE` — verify in the node's "next execution" preview).
- Activate the workflow (toggle in the n8n UI). Note: with local Docker, the machine must be on at 09:30 — acceptable for a demo project.
- Keep the Manual Trigger **alongside** the Schedule Trigger, both feeding the same branches: the schedule drives production runs, the manual trigger serves the UI's "Execute workflow" **and the CLI** — `n8n execute` refuses to start a workflow that has no manual/execute trigger, and the headless verification loop depends on it.

## Acceptance criteria
- [x] Scheduled execution runs unattended — verified in production: the 2026-07-30 09:30 run executed on schedule and committed both the payload and the index entry.
- [x] Digest + Discord message produced without manual action — verified with a temporary near-term cron: the scheduler fired at its tick and the full pipeline ran hands-free (publish commit `709a61c` landed 9 seconds after trigger time, Discord notified)
