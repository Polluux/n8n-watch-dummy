# Spec 03 — AI selection & deduplication (LLM #1)

## Goal
From the ≤60 normalized items, the LLM selects the ~10 most relevant, deduplicated links.

## Design
- Node: **Basic LLM Chain** (or AI Agent) + **Google Gemini Chat Model** (`gemini-2.5-flash` on the free tier is plenty; temperature low).
- Input: the full normalized list as JSON in the prompt.
- Prompt requirements:
  - a stated editorial line (e.g. "software engineering, AI/LLM tooling, DevOps — for a French consulting engineer")
  - deduplicate near-identical stories (same event covered by several sources → keep the best single link)
  - return **only** a JSON array of the selected items' `url` values, max 10
- A **Code** node then filters the original items by the returned URLs — the LLM selects,
  it never rewrites item data (prevents hallucinated URLs from leaking downstream).

## Acceptance criteria
- [ ] Output is ≤10 items, all present verbatim in the input list
- [ ] Feeding the same story twice from two sources yields only one of them
- [ ] Non-JSON / malformed model output makes the node fail visibly (no silent empty digest)
