# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Daily tech-watch digest built as an n8n workflow: N RSS sources → normalize → Gemini selects ≤10 links → Gemini extracts structured JSON → publish the day's JSON payload to GitHub Pages (rendered client-side) → Discord notification. Runs daily at 09:30 Europe/Paris. Demo project ("dummy"), free-tier only.

Development is **spec-driven**: one spec per phase in `specs/01..07`, each with acceptance criteria checked off as they are verified. Read `PLAN.md` first, then the spec for the phase being worked on. One commit per phase (`build(<topic>): spec N finished`). All phases (1–7) are done and verified.

## Critical: workflow sync protocol

The n8n editor works on its own database (Docker volume `n8n_data`), and `workflow/tech-watch.json` is a git-tracked snapshot. **There is no automatic sync**, and an import silently overwrites UI edits. Rules:

- One editor at a time: either the user edits in the UI, or Claude edits the JSON.
- After UI edits: `./scripts/export-workflow.sh` (syncs DB → repo, then `git diff`).
- After JSON edits: import with `docker cp workflow/tech-watch.json n8n-watch:/tmp/tech-watch.json && docker exec n8n-watch n8n import:workflow --input=/tmp/tech-watch.json`
- **Always run the export script before editing the JSON**, to capture any UI changes.
- The workflow id is pinned (`TechWatchDummy01`) so import updates in place.
- **An import deactivates the workflow** (`import:workflow` prints `Deactivating workflow "tech-watch"`), which silently stops the 09:30 schedule. `update:workflow --active=true` / `publish:workflow` are no-ops in this n8n version — they warn about a restart and write nothing, and a restart does not help (`workflow_entity.active` stays `0`, `workflow_published_version` stays empty). **Re-activate with the toggle in the UI after every import**, and check with:<br>`docker cp n8n-watch:/home/node/.n8n/database.sqlite /tmp/db.sqlite` then `select active, activeVersionId from workflow_entity;` (the container has no `sqlite3`). Activation is not stored in the exported JSON, so git cannot reveal the regression.

## Commands

```bash
docker compose up -d                  # n8n at http://localhost:5678 (TZ Europe/Paris)
./scripts/export-workflow.sh          # sync workflow: n8n DB → repo JSON

# Headless execution (the verification loop used for every acceptance criterion):
docker exec -e N8N_RUNNERS_BROKER_PORT=5680 n8n-watch n8n execute \
  --id TechWatchDummy01 --rawOutput > /tmp/exec.json
# N8N_RUNNERS_BROKER_PORT is required: the CLI spawns its own task broker and
# port 5679 is taken by the live instance. Output mixes log lines with JSON —
# find the first '{' and parse from there (use json.JSONDecoder().raw_decode;
# trailing content after the document is possible).
# Then inspect data.resultData.runData[<node name>][0].data.main[0] per node.

# Serve the Pages site locally (fetch('digests.json') fails on file://):
python3 -m http.server -d docs/
```

There is no `n8n delete:workflow` in this n8n version — delete via the UI.

Publishing quirks: GitHub file writes go through HTTP Request nodes on the contents API (`PUT` = create-or-update via optional `sha`), not the GitHub node (its Create/Edit split fails on the first-run vs re-run cases). Discord v2 node with webhook auth: do NOT set `resource` (hidden, defaults to `webhook`); operation is `sendLegacy`. A workflow run that fails mid-publish may already have committed the payload — re-runs are safe (idempotent by design), but `git pull` before local work: **the workflow commits to origin/main**.

## Architecture

Pipeline (single workflow `tech-watch`, `workflow/tech-watch.json`):

```
Schedule Trigger (cron 30 9 * * *, Europe/Paris) + Manual Trigger (same fan-out — required:
`n8n execute` cannot start a workflow without one, so the CLI verification loop needs it)
 → Sources (Code: config list of {name, tag, url} — THE place to add/remove feeds)
 → Loop sources (Split In Batches) → Fetch RSS (url from item; onError continue)
 → Tag items (Code: re-attach source tag+name — RSS Read drops input fields) → loop back;
   done-output →
 → Normalize (Code): strip HTML, drop >48h, sort desc, cap 60, stamp numeric `id`
 → Recent dates (Code: the 7 days before today) → Get recent digests (HTTP GET per day, GitHub
   contents API with the raw media type; onError continue — a 404 is a day without a digest)
 → Drop published (Code: cross-day dedup — drops candidates whose URL already shipped, bundles
   the survivors as `{data, covered}`)
 → Select links (LLM Chain + "Gemini Flash" sub-node) → Filter selected (Code)
 → Extract data (LLM Chain + Structured Output Parser "Structured JSON") → Validate extraction (Code)
 → Bundle records (Aggregate) → Write intro (LLM Chain) → Build payload (Code: pure JSON —
   its output IS the daily artifact docs/digests/YYYY-MM-DD.json, phase 5's deliverable)
 → publish: Get index / Get existing payload (HTTP GET, GitHub contents API)
 → Prepare publish (Code: PUT bodies + Discord text) → Commit payload (PUT)
 → Index changed? (IF) → Commit index (PUT, only if date new) → Notify Discord (webhook)
```

Design invariants (do not regress):

- **Identity fields (title/url/source) never round-trip through an LLM** — models can subtly alter strings they "copy", URLs included. LLM steps receive items with numeric `id`s and return only ids + judgment fields (`category`, `tags`, `tldr`); Code nodes rebuild identity fields from the originals by id and throw on any unknown id / malformed output (fail loudly, no silent empty digest).
- **LLM chains run once per input item.** Batch calls require bundling first — either an Aggregate node or a Code node returning `[{json: {data: [...]}}]` (Drop published and Filter selected do the latter).
- **A link publishes at most once per 7-day window, enforced in code — never by the model.** Normalize's 48h window is wider than the 24h run cadence, so every item is a candidate on two consecutive days. "Drop published" reads the last 7 days' payloads and removes already-published URLs *before* the LLM sees them, comparing on a canonical URL (lowercase host, no `www.`, no fragment, tracking params stripped) so `?utm_*` variants of one link still match. "Filter selected" resolves the returned ids against that deduped list, so an excluded item cannot be re-admitted. The prompt additionally receives the excluded headlines under "Already covered" to discourage a second source's take on the same story — that half is model judgment, the URL exclusion is not. **The window is the 7 days *before* today, never today**: a same-day re-run must be free to re-select the links it published that morning.
- **Model is `models/gemini-flash-latest`** (credential: "Google Gemini(PaLM) Api" in the n8n UI, never in the repo). Keep the rolling alias: pinned versions 404 for new API keys ("no longer available to new users"). To see what a key can use, GET `/v1beta/models` via an n8n HTTP Request node with the stored credential.
- **The workflow ships data, never markup.** Its final output is a JSON payload (`docs/digests/YYYY-MM-DD.json`) plus its date registered in `docs/digests.json` — which is a **pure index** (array of date strings, nothing else; day data lives only in the payload, the homepage fetches recent payloads for subtitles). All rendering is client-side in two static pages the workflow never touches: `docs/index.html` (homepage, lists the date index) and `docs/digest.html` (viewer, renders `?d=YYYY-MM-DD`). Layout edits restyle all digests retroactively. The pipeline has no run-time dependency on the site or the repo's HTML.
- **Viewer security model: third-party strings reach the DOM via `textContent` only — never `innerHTML` — and hrefs are http(s)-only.** Normalize drops non-http(s) URLs at ingestion and the viewer refuses to set such an href at render (defense in depth). Verified with a DOM-stub test (hostile payload through the real viewer script). Tailwind via browser CDN is the only allowed external asset. Same-day re-runs must replace, not duplicate, the day's index entry.
- **Docs stay source-agnostic.** The canonical feed list is the workflow's "Sources" Code node; specs/PLAN/README must not enumerate the feeds (they reference the workflow JSON instead). Adding/removing a source is a one-line edit there.

Feed quirks: some feeds reject n8n's user-agent with HTTP 406 — test new feeds in the workflow, not just with curl. Per-feed UI counts are raw; spec numbers are post-Normalize (48h filter + cap). Feeds occasionally return 0 items under rapid repeated runs; the continue-on-error fetch absorbs it.

## Verification pattern

A phase is done when its spec's acceptance criteria are demonstrated against a real headless execution (not reasoned about): run the workflow, parse `runData`, assert counts/shapes/invariants, then check the boxes in the spec with the measured numbers.
