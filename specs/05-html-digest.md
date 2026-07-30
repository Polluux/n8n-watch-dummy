# Spec 05 — Digest payload + client-side rendering (LLM #3 + viewer page)

## Goal
The workflow publishes the day's digest as **data** (JSON); the site renders it client-side through a shared viewer page. Every digest — past and future — is displayed with the current layout, so visual coherence is total and retroactive.

## Design
Two parts:

1. **LLM #3 — editorial intro** ("Write intro"). Basic LLM Chain + Google Gemini Chat Model (shared "Gemini Flash" sub-node). Input: spec 04's records (bundled by "Bundle records"). Output: 2–3 sentences in French, plain text, no markdown/HTML/emoji, themes not titles.

2. **"Build payload" (Code node)** — assembles the publishable JSON:

```json
{
  "date": "YYYY-MM-DD (Europe/Paris)",
  "generatedAt": "ISO-8601",
  "intro": "…",
  "count": 10,
  "items": [ { "title", "url", "source", "sourceName", "publishedAt", "category", "tags", "tldr" } ]
}
```

   **The daily JSON artifact `docs/digests/YYYY-MM-DD.json` is this phase's deliverable** — its content is exactly the Build payload output. Phase 6 only *publishes* it (GitHub commit + date-index entry + Discord); it adds no content. The workflow produces **no HTML anywhere**.

3. **Viewer page** [`docs/digest.html`](../docs/digest.html) — static, committed once, never touched by the workflow. Reads `?d=YYYY-MM-DD` (validated), fetches `digests/<d>.json`, renders via component-style functions (`Card`, `Section`, `Digest`). Styling: Tailwind browser CDN (only external asset, same as homepage). Layout changes = edit this file, push — all digests restyle retroactively.

## Security model
All third-party strings (feed titles, LLM text) reach the DOM exclusively via `textContent` — `innerHTML` is never used for data. Escaping is structural, not a discipline to maintain.

## Acceptance criteria
- [x] Workflow output is pure data matching the payload shape above — verified via `n8n execute`: 10 items, French intro, valid date/ISO timestamps, no markup fields
- [x] The day's artifact `docs/digests/YYYY-MM-DD.json` is generated from the run and renders in the viewer — verified: `docs/digests/2026-07-29.json` written from the live run; served locally (`python3 -m http.server -d docs/`), both `digest.html` and the payload respond 200 and parse
- [x] All digests share one layout, retroactively — by construction: a single viewer page renders every payload; no HTML is baked at publish time
- [x] A title containing `<script>`/`<img onerror>` renders as text — by construction (`textContent` only); verified by injecting a hostile payload through the viewer's render path
- [x] Viewer handles bad input: missing/malformed `?d=`, unknown date → readable error with a link home (no blank page)
- [x] The only loadable external resource on the viewer is the Tailwind CDN
