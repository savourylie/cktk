---
name: "interact-html"
description: "Use when the user wants an agent-user interaction — clarifying questions, option picks, design directions, decision briefings — rendered as a local interactive HTML page instead of terminal text, answered in the browser, and archived as a decision record under .ai/interactions/. Collects answers via a one-shot localhost server or a paste-back fallback. Prefer explicit invocation with $interact-html."
---

# Render an Interaction as HTML

Turn the current agent-user interaction into a self-contained HTML page the user answers in a browser. Lifecycle: compose → serve → open → collect → confirm → archive. The archived page is a self-documenting decision record.

## Portable interaction rules

- Compose from populated invocation input when available; otherwise from open questions in the surrounding conversation. Treat a missing or unsubstituted host placeholder as no argument.
- Show every candidate option with a stable id, a distinguishing label, and a one-sentence description. Never assume an option limit or an automatically supplied catch-all choice — when "none of these" is plausible, add an explicit free-text field to that question yourself.
- One page per interaction; follow-up rounds are new invocations.
- Read applicable repository guidance (`AGENTS.md`, `CLAUDE.md`, or equivalent) before composing.

## Prerequisites

1. Any project directory; git optional (the `.gitignore` step only runs in a git repo).
2. `python3` optional — without it the page still works via the paste channel.
3. On headless hosts, print the page path instead of opening a browser.

## Workflow

1. **Compose.** Kebab-case `SLUG` (≤40 chars; suffix `-2`, `-3`… on collision). Content model: one-paragraph briefing + 1–7 questions (`single` | `multi` | `text`; choice questions have 2+ options with id, label, description; optional inline-CSS/SVG compare-grid). Announce in one line.
2. **Workspace.** `mkdir -p <root>/.ai/interactions/{active,archive}`. In a git repo, if `git check-ignore -q .ai/interactions/` fails, append `.ai/interactions/` to the root `.gitignore` and announce. Never commit.
3. **Channel.** No python3 → `PORT=0` (paste-only). Else background `python3 <skill>/scripts/serve_answers.py --dir <root>/.ai/interactions/active --slug <SLUG> --timeout 900`; read `<SLUG>.port` within 5s, else `PORT=0`.
4. **Render.** Fill every at-sign placeholder in `assets/interaction-template.html` (title, slug, timestamp, port, empty body class, briefing HTML, question cards; the two RESOLVED slots become HTML comments reading exactly `RESOLVED-BANNER-SLOT` / `RESOLVED-ANSWERS-SLOT`). Write to `active/<SLUG>.html`; verify no at-sign placeholder remains; template class names are canonical.
5. **Open & wait.** macOS: `open <path>`; otherwise print the path. Poll for `<SLUG>.answers.json` in bounded increments (~90s per run, ~10 min total); a pasted JSON blob in chat wins — then `curl -s -X POST http://127.0.0.1:<PORT>/cancel`. Timeout → re-prompt: wait, paste, or abandon (abandon deletes the active page; the server times out on its own).
6. **Confirm.** Parse the answers JSON (identical shape from both channels: `interaction`, `submitted_at`, `channel`, `answers[]` with `id`/`question`/`type`/`selected`/`selected_labels`/`text`, `notes`). Restate decisions compactly; follow up only on empty, contradictory, or interpretation-needing answers.
7. **Archive.** Replace the two slot comments with the `.resolved-banner` div and `.decisions-section`; set body class `resolved`; add `selected` to chosen tiles; move to `archive/<YYYY-MM-DD>-<SLUG>.html`; delete `answers.json`/`.port` leftovers; report the archive path.

## Safety rules

- Write only under `.ai/interactions/` plus at most one `.gitignore` line; never commit; never touch other repo files.
- The page makes no external requests; its only endpoint is 127.0.0.1 on the one-shot port. Treat pages as local-only, like `.ai/handoffs/`.
- Never fabricate answers; if both channels fail, ask in the terminal.
- Skip for trivial yes/no confirmations.
