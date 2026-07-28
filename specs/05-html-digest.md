# Spec 05 — HTML digest from shared template (LLM #3 + Code node)

## Goal
Every daily digest is rendered from the same repo-versioned template, so all pages are
visually coherent. The LLM contributes **content only**, never page structure.

## Design

Two steps:

1. **LLM #3 — editorial intro.** Basic LLM Chain + Google Gemini Chat Model.
   Input: spec 04's JSON array. Output: 2–3 sentences in French summarizing today's
   themes (plain text, no HTML, no markdown). This keeps an AI touch in the page
   while the layout stays deterministic.

2. **Code node — template rendering.**
   - Template lives at [`templates/digest.html`](../templates/digest.html) — single
     source of truth, versioned in the repo. The workflow fetches it at run time from
     the raw GitHub URL (HTTP Request node), so template updates never require touching
     the workflow. (Fallback if offline dev is needed: paste it into the Code node, but
     the repo file stays authoritative.)
   - Placeholders (mustache-style, replaced by the Code node):
     - `{{DATE}}` — YYYY-MM-DD
     - `{{INTRO}}` — the LLM's editorial intro (escaped)
     - `{{ITEMS}}` — the per-item HTML blocks, built by the Code node from the JSON
       (grouped by `category`; each block: linked title `target="_blank"`, source, tags, tldr)
     - `{{GENERATED_AT}}` — ISO timestamp
   - **All third-party strings HTML-escaped** by the Code node (titles come from the open web).

## Template requirements (`templates/digest.html`)
- Styling: **Tailwind CSS via the browser CDN build** (`@tailwindcss/browser@4`) — the
  only external asset allowed. No build step; acceptable for a demo since the pages are
  online-only anyway (the homepage fetches the manifest). If this ever becomes a real
  product, switch to the Tailwind CLI generating a committed `docs/assets/site.css`.
- The template contains a **commented item-markup pattern** (section per category, card
  per item, with the exact Tailwind classes). The Code node generating `{{ITEMS}}` must
  follow it verbatim — that comment is the layout contract between template and workflow.
- Readable at mobile width; `<title>` "Veille tech — {{DATE}}"
- A "← Accueil" link back to `../index.html`
- Footer: "Généré par n8n + Gemini" + `{{GENERATED_AT}}`

## Acceptance criteria
- [ ] Two digests generated on different days differ **only** in content, not structure/styling
- [ ] Editing `templates/digest.html` changes the next run's output with no workflow change
- [ ] A title containing `<script>` renders as text, not markup
- [ ] LLM intro output containing accidental HTML/markdown is neutralized by escaping
- [ ] Saved output renders correctly in a browser (Tailwind CDN is the only network request)
- [ ] Generated item blocks use exactly the classes from the template's commented pattern
