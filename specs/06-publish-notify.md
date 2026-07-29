# Spec 06 — Publish to GitHub Pages (homepage index) & notify Discord

## Goal
Each digest goes live at its own URL, the homepage automatically lists all digests
(latest first), and a Discord message announces the new one.

## Publishing model
- `docs/index.html` (homepage) and `docs/digest.html` (viewer) — **static pages,
  committed once by hand**, never touched by the workflow. The homepage fetches
  `digests.json` and lists digests (latest highlighted), linking each to
  `digest.html?d=YYYY-MM-DD`; the viewer fetches and renders the day's JSON.
- `docs/digests.json` — a **pure index**: a JSON array of date strings
  (`["2026-07-29", ...]`). No other data — `count`/`intro` live only in each day's
  payload; the homepage fetches recent payloads for its subtitles (capped by
  `DETAIL_LIMIT` in `index.html`). Needed because static hosting can't list a
  directory; kept minimal so nothing is duplicated.
- `docs/digests/YYYY-MM-DD.json` — the digest payload from spec 05 (data, no markup).

The workflow only writes a new data file and registers its date — no HTML anywhere
in the pipeline.

## Workflow steps (GitHub node)
1. **Get** `docs/digests.json` → Code node: parse, add today's date if absent
   (idempotent for same-day re-runs), sort desc.
2. **Create/Update** `docs/digests/YYYY-MM-DD.json` — commit message `digest: YYYY-MM-DD`.
3. **Update** `docs/digests.json` (only when the date was newly added).
- Note: GitHub file updates need the current file SHA; the n8n GitHub node's "Edit"
  handles this, but "Edit" fails on a missing file and "Create" on an existing one —
  handle the first-run case for each daily file.
- Pages (enabled in spec 01) republishes automatically within ~1 minute.

## Notify (Discord)
- **Discord node, webhook mode**, posting to your private channel:
  - content: date, item count, top 3 titles, direct link to
    `https://polluux.github.io/n8n-watch-dummy/digest.html?d=YYYY-MM-DD`
- Chosen over a true DM because a DM needs a Discord bot application + token + the bot
  sharing a server with you — 3 extra setup steps for the same proof. If you want the DM
  anyway: create a bot, use n8n's Discord Bot credential, target yourself as recipient.
- Discord runs **after** both GitHub commits succeed (no announcement of a failed publish).

## Acceptance criteria
- [ ] After a run, the digest renders at `digest.html?d=<date>` **and** is listed on the homepage
- [ ] Homepage shows digests latest-first with the newest visually highlighted
- [ ] Re-running the same day overwrites the data file and leaves exactly one index entry for that date
- [ ] Discord message arrives with a working direct link to the day's digest
- [ ] If any GitHub step fails, no Discord message is sent
