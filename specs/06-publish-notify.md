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

## Workflow steps
Implemented with **HTTP Request nodes against GitHub's contents API** (using the
stored GitHub credential as a predefined credential type) rather than the GitHub
node: `PUT /repos/{owner}/{repo}/contents/{path}` is a single create-or-update call
(include the file's `sha` to update, omit it to create), which avoids the GitHub
node's "Edit fails on missing file / Create fails on existing file" split.

1. **Get index** + **Get existing payload** (GETs; the payload GET has
   continue-on-error — a 404 just means first publish of the day).
2. **Prepare publish** (Code): decode the index, add today's date if absent
   (idempotent), build both PUT bodies (base64 content, `sha` when updating) and the
   Discord message.
3. **Commit payload** (PUT, `digest: YYYY-MM-DD`) → **Index changed?** (IF) →
   **Commit index** (PUT, only when the date is new).
- Pages (enabled in spec 01) republishes automatically within ~1 minute.
- n8n quirk: with webhook authentication the Discord v2 node hides the `resource`
  parameter (defaults to `webhook`) and the operation is `sendLegacy` — setting
  `resource: message` explicitly breaks the node's internal routing.

## Notify (Discord)
- **Discord node, webhook mode**, posting to your private channel:
  - content: date, item count, top 3 titles, direct link to
    `https://polluux.github.io/n8n-watch-dummy/digest.html?d=YYYY-MM-DD`
- Chosen over a true DM because a DM needs a Discord bot application + token + the bot
  sharing a server with you — 3 extra setup steps for the same result. If you want the DM
  anyway: create a bot, use n8n's Discord Bot credential, target yourself as recipient.
- Discord runs **after** both GitHub commits succeed (no announcement of a failed publish).

## Acceptance criteria
- [x] After a run, the digest renders at `digest.html?d=<date>` **and** is listed on the homepage — verified live: workflow commit `f70e913` served by Pages (new `generatedAt` confirmed), viewer 200, live index contains the date
- [x] Homepage shows digests latest-first with the newest visually highlighted — index sorted desc by the workflow; homepage badges entry 0 ("dernier")
- [x] Re-running the same day overwrites the data file and leaves exactly one index entry for that date — verified live: second run updated the payload via its `sha` and **skipped** the index commit (IF branch false); live index has exactly one entry
- [x] Discord message arrives with a working direct link to the day's digest — webhook returned `success: true`; content = date, count, top-3 titles, viewer link (user eyeball: check the channel)
- [x] If any GitHub step fails, no Discord message is sent — by construction (strictly sequential: commits precede Discord; any node error aborts the run) and observed live: the first run errored at the Discord node itself, after its payload commit — no message was sent
