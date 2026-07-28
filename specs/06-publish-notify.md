# Spec 06 — Publish to GitHub Pages (homepage index) & notify Discord

## Goal
Each digest goes live at its own URL, the homepage automatically lists all digests
(latest first), and a Discord message announces the new one.

## Publishing model
- `docs/index.html` — **static homepage, committed once by hand** (phase 0), never
  touched by the workflow. On load it fetches `digests.json` and renders the list of
  digests with the latest highlighted.
- `docs/digests.json` — manifest the workflow appends to. One entry per run:

```json
{ "date": "YYYY-MM-DD", "path": "digests/YYYY-MM-DD.html", "count": 8, "intro": "…" }
```

- `docs/digests/YYYY-MM-DD.html` — the rendered digest from spec 05.

This avoids HTML surgery on the homepage: the workflow only writes a new file and
appends one JSON entry.

## Workflow steps (GitHub node)
1. **Get** `docs/digests.json` → Code node: parse, remove any existing entry for
   today's date (re-runs overwrite, not duplicate), append today's entry, sort by date desc.
2. **Create/Update** `docs/digests/YYYY-MM-DD.html` — commit message `digest: YYYY-MM-DD`.
3. **Update** `docs/digests.json`.
- Note: GitHub file updates need the current file SHA; the n8n GitHub node's "Edit"
  handles this, but "Edit" fails on a missing file and "Create" on an existing one —
  handle the first-run case for each daily file.
- Pages (enabled in spec 01) republishes automatically within ~1 minute.

## Notify (Discord)
- **Discord node, webhook mode**, posting to your private channel:
  - content: date, item count, top 3 titles, direct link to
    `https://<user>.github.io/n8n-watch-dummy/digests/YYYY-MM-DD.html`
- Chosen over a true DM because a DM needs a Discord bot application + token + the bot
  sharing a server with you — 3 extra setup steps for the same proof. If you want the DM
  anyway: create a bot, use n8n's Discord Bot credential, target yourself as recipient.
- Discord runs **after** both GitHub commits succeed (no announcement of a failed publish).

## Acceptance criteria
- [ ] After a run, the digest is live at its dated URL **and** listed on the homepage
- [ ] Homepage shows digests latest-first with the newest visually highlighted
- [ ] Re-running the same day overwrites the page and leaves exactly one manifest entry for that date
- [ ] Discord message arrives with a working direct link to the day's digest
- [ ] If any GitHub step fails, no Discord message is sent
