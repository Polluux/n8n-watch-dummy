# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Daily tech-watch digest built as an n8n workflow: N RSS sources → normalize →
Gemini selects ≤10 links → Gemini extracts structured JSON → render HTML digest
from a shared template → commit to GitHub Pages → Discord notification.
Runs daily at 09:30 Europe/Paris. Demo project ("dummy"), free-tier only.

Development is **spec-driven**: one spec per phase in `specs/01..07`, each with
acceptance criteria checked off as they are verified. Read `PLAN.md` first, then the
spec for the phase being worked on. One commit per phase (`build(<topic>): spec N
finished`). All phases (1–7) are done and verified.

## Critical: workflow sync protocol

The n8n editor works on its own database (Docker volume `n8n_data`), and
`workflow/tech-watch.json` is a git-tracked snapshot. **There is no automatic sync**,
and an import silently overwrites UI edits (this happened once — a user's UI edit was
lost). Rules:

- One editor at a time: either the user edits in the UI, or Claude edits the JSON.
- After UI edits: `./scripts/export-workflow.sh` (syncs DB → repo, then `git diff`).
- After JSON edits: import with
  `docker cp workflow/tech-watch.json n8n-watch:/tmp/tech-watch.json && docker exec n8n-watch n8n import:workflow --input=/tmp/tech-watch.json`
- **Always run the export script before editing the JSON**, to capture any UI changes.
- The workflow id is pinned (`TechWatchDummy01`) so import updates in place.

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

Publishing quirks: GitHub file writes go through HTTP Request nodes on the contents
API (`PUT` = create-or-update via optional `sha`), not the GitHub node (its
Create/Edit split fails on the first-run vs re-run cases). Discord v2 node with
webhook auth: do NOT set `resource` (hidden, defaults to `webhook`); operation is
`sendLegacy`. A workflow run that fails mid-publish may already have committed the
payload — re-runs are safe (idempotent by design), but `git pull` before local work:
**the workflow commits to origin/main**.

## Architecture

Pipeline (single workflow `tech-watch`, `workflow/tech-watch.json`):

```
Schedule Trigger (cron 30 9 * * *, Europe/Paris; "Execute workflow" in the UI still runs it manually)
 → N× RSS Read (onError: continueRegularOutput) → N× Set "Tag <src>" (stamps a short source tag)
 → Merge (append, N inputs)
 → Normalize (Code): strip HTML, drop >48h, sort desc, cap 60, stamp numeric `id`
 → Bundle items (Aggregate) → Select links (LLM Chain + "Gemini Flash" sub-node) → Filter selected (Code)
 → Extract data (LLM Chain + Structured Output Parser "Structured JSON") → Validate extraction (Code)
 → Bundle records (Aggregate) → Write intro (LLM Chain) → Build payload (Code: pure JSON —
   its output IS the daily artifact docs/digests/YYYY-MM-DD.json, phase 5's deliverable)
 → publish: Get index / Get existing payload (HTTP GET, GitHub contents API)
 → Prepare publish (Code: PUT bodies + Discord text) → Commit payload (PUT)
 → Index changed? (IF) → Commit index (PUT, only if date new) → Notify Discord (webhook)
```

Design invariants (each learned the hard way — do not regress):

- **Identity fields (title/url/source) never round-trip through an LLM.** Gemini
  translated a French word inside a URL slug while "copying it exactly"
  (`affirme` → `affirms`). LLM steps receive items with numeric `id`s and return only
  ids + judgment fields (`category`, `tags`, `tldr`); Code nodes rebuild identity
  fields from the originals by id and throw on any unknown id / malformed output
  (fail loudly, no silent empty digest).
- **LLM chains run once per input item.** Batch calls require bundling first — either
  an Aggregate node or a Code node returning `[{json: {data: [...]}}]` (Filter
  selected does the latter; a redundant Aggregate node was removed).
- **Model is `models/gemini-flash-latest`** (credential: "Google Gemini(PaLM) Api" in
  the n8n UI, never in the repo). Pinned versions like `gemini-2.5-flash` 404 for
  new API keys ("no longer available to new users") — keep the rolling alias. To see
  what a key can use, GET `/v1beta/models` via an n8n HTTP Request node with the
  stored credential (see git history for the tmp-list-models workflow).
- **The workflow ships data, never markup.** Its final output is a JSON payload
  (`docs/digests/YYYY-MM-DD.json`) plus its date registered in `docs/digests.json` —
  which is a **pure index** (array of date strings, nothing else; day data lives only
  in the payload, the homepage fetches recent payloads for subtitles). All
  rendering is client-side in two static pages the workflow never touches:
  `docs/index.html` (homepage, lists the manifest) and `docs/digest.html` (viewer,
  renders `?d=YYYY-MM-DD`). Layout edits restyle all digests retroactively. This
  replaced an earlier design that fetched an HTML template from raw GitHub at run
  time (rejected: run-time coupling to GitHub, push-before-effect, baked layout).
- **Viewer security model: third-party strings reach the DOM via `textContent`
  only — never `innerHTML`.** Verified with a DOM-stub test (hostile payload through
  the real viewer script). Tailwind via browser CDN is the only allowed external
  asset. Same-day re-runs must replace, not duplicate, the day's manifest entry.

- **Docs stay source-agnostic.** The canonical feed list is the workflow's RSS Read
  nodes; specs/PLAN/README must not enumerate the feeds (they reference the workflow
  JSON instead). Adding/removing a source touches only the workflow.

Feed quirks: some feeds reject n8n's user-agent with HTTP 406 (InfoQ does — that's why
it isn't a source); test new feeds in the workflow, not just with curl. Per-feed UI
counts are raw; spec numbers are post-Normalize (48h filter + cap). hnrss occasionally
returns 0 items under rapid repeated runs; the continue-on-error branches absorb it.

Roadmap (PLAN.md): make sources config-driven — a `{url, tag}` list looped over
instead of per-source branches. The RSS Read node drops input fields, so the tag must
be re-attached inside the loop (Split In Batches, or HTTP Request + XML node).

## Verification pattern

A phase is done when its spec's acceptance criteria are demonstrated against a real
headless execution (not reasoned about): run the workflow, parse `runData`, assert
counts/shapes/invariants, then check the boxes in the spec with the measured numbers.
