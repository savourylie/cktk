---
name: interact-html
description: "Render an agent-user interaction — clarifying questions, option picks, design directions, decision briefings — as a self-contained interactive HTML page under .ai/interactions/, collect the user's answers through a local one-shot server or a paste-back fallback, then archive the resolved page as a decision record. Use when the user wants to answer questions in a browser instead of the terminal, asks to see options as a page, or has expressed a standing preference for HTML interactions. Triggers on: /interact-html, ask via browser, render questions as a page, show me the options visually, HTML interaction, interactive page for this decision."
user-invocable: true
disable-model-invocation: false
argument-hint: "[topic, questions, or options to render]"
---

**Invocation input:** `$ARGUMENTS`

# Render an Interaction as HTML

Turn the current agent-user interaction into a self-contained HTML page the user answers in a browser, instead of terminal text. Lifecycle: compose → serve → open → collect → confirm → archive. The archived page is a self-documenting decision record.

## Portable interaction rules

- Compose the interaction from populated invocation input when available; otherwise from the open questions in the surrounding conversation. Treat a missing, empty, or unsubstituted host placeholder as no argument.
- Show every candidate option with a stable id and a distinguishing label plus a one-sentence description. Never assume an option limit or an automatically supplied catch-all choice — when "none of these" is plausible for a question, add an explicit free-text field to that question yourself.
- One page per interaction; follow-up rounds are new invocations.
- Read applicable repository guidance (`AGENTS.md`, `CLAUDE.md`, or equivalent) before composing, so option wording matches project terms.
- Refer to other skills by name; use host-native syntax if known.

## Prerequisites

1. Any project directory. Git is optional — the `.gitignore` step below only runs inside a git repo.
2. `python3` is optional — without it the page still works through the paste channel.
3. A browser the user can open. On non-desktop or headless hosts, print the page path instead of opening it.

## Argument grammar

| Invocation | Meaning |
| --- | --- |
| `<free-form text>` | Compose the interaction from this instruction plus conversation context. |
| (empty) | Render the pending open questions from the surrounding conversation; if none exist, ask in the terminal what the interaction should cover. |

No mode tokens, no ticket coupling.

## Phase 1: Compose the Interaction

1. Derive `SLUG`: kebab-case from the topic, at most 40 characters. If `.ai/interactions/active/<SLUG>.html` already exists, append `-2`, `-3`, … until free.
2. Draft the content model before touching files: a one-paragraph context briefing, then 1–7 questions. Each question has an `id` (`q1`…`qN`), a `type` (`single` | `multi` | `text`), a prompt, and — for choice questions — two or more options each with an `id`, a short label, and a one-sentence description. Optionally add a compare-grid of visual variants (inline CSS/SVG only) keyed to option ids when options are genuinely visual.
3. Announce the plan in one terminal line: `Rendering N questions to .ai/interactions/active/<SLUG>.html`.

## Phase 2: Prepare the Workspace

1. Resolve the project root (`git rev-parse --show-toplevel` in a git repo; otherwise the current directory). Run `mkdir -p <root>/.ai/interactions/active <root>/.ai/interactions/archive`.
2. In a git repo: if `git check-ignore -q .ai/interactions/` fails, append a `.ai/interactions/` line to the project root `.gitignore` and announce it in one line. Never commit anything.

## Phase 3: Start the Return Channel

1. If `python3` is unavailable, set `PORT=0` (paste-only mode) and skip to Phase 4.
2. Start the collector in the background:
   ```
   python3 <this-skill>/scripts/serve_answers.py --dir <root>/.ai/interactions/active --slug <SLUG> --timeout 900
   ```
3. Wait up to 5 seconds for `<root>/.ai/interactions/active/<SLUG>.port` to appear and read `PORT` from it. If it never appears, set `PORT=0` and continue.

## Phase 4: Render the Page

1. Read `assets/interaction-template.html` from this skill's folder.
2. Write `.ai/interactions/active/<SLUG>.html`, replacing every at-sign placeholder: `@INTERACTION-TITLE`, `@INTERACTION-SLUG`, `@GENERATED-AT` (ISO timestamp), `@SERVER-PORT` (number, or `0`), `@BODY-CLASS` (empty string), `@INTERACTION-CONTEXT` (briefing HTML), `@QUESTION-CARDS` (question-card markup from the Phase 1 model, using the template's canonical class contract), and the two slot placeholders `@RESOLVED-BANNER` / `@RESOLVED-ANSWERS` — each replaced by an HTML comment whose text is exactly `RESOLVED-BANNER-SLOT` / `RESOLVED-ANSWERS-SLOT` (the archive pass consumes them).
3. Verify no at-sign placeholder remains in the rendered page body. Do not rename template classes — they are canonical and the inline script depends on them.

## Phase 5: Open and Wait

1. On macOS run `open <absolute page path>`. Otherwise print the absolute path and ask the user to open it in a browser.
2. Tell the user both channels exist: submit inside the page, or — if the page shows its fallback panel — copy the JSON blob and paste it into the chat.
3. Poll for `.ai/interactions/active/<SLUG>.answers.json` in bounded increments (a shell `until [ -f … ]` loop capped at roughly 90 seconds per run, up to about 10 minutes total). Between increments, check whether the user pasted the JSON blob into the chat instead — a pasted blob wins; when it does and a server is running, release it with `curl -s -X POST http://127.0.0.1:<PORT>/cancel`.
4. If nothing arrives within the total bound, stop polling and re-prompt in the terminal: keep waiting, answer by paste, or abandon. On abandon, delete the active page and stop — the server exits on its own timeout.

## Phase 6: Confirm

1. Parse the answers JSON (shape below). Both channels produce it identically.
2. Restate every decision in one compact terminal block (question → chosen label(s) or text). Ask a follow-up only when an answer is empty, contradictory, or free-text that needs interpretation.
3. Use the confirmed answers as the interaction's outcome for the ongoing task.

## Phase 7: Archive

1. Rewrite the page: replace the `RESOLVED-BANNER-SLOT` comment with a `.resolved-banner` div (status, resolution date, channel); replace the `RESOLVED-ANSWERS-SLOT` comment with a `.decisions-section` listing each question and its chosen answer(s); change the body class to `resolved` (template CSS then hides the answer bar and makes tiles inert); add `selected` to each chosen option tile.
2. Move the file to `.ai/interactions/archive/<YYYY-MM-DD>-<SLUG>.html` (`date +%F`).
3. Delete any `<SLUG>.answers.json` and `<SLUG>.port` leftovers from `active/`.
4. Report the archive path in the final summary.

## Answers JSON shape

```json
{
  "interaction": "<slug>",
  "submitted_at": "<ISO-8601>",
  "channel": "server | paste",
  "answers": [
    { "id": "q1", "question": "…", "type": "single|multi|text",
      "selected": ["opt-a"], "selected_labels": ["Label A"], "text": "" }
  ],
  "notes": ""
}
```

## Make it the default

When the user asks how to get HTML interactions every time, offer this snippet for their global `CLAUDE.md` or a repo `AGENTS.md`:

```markdown
## Interactions
When you need my input mid-task — clarifying questions, option picks, design
direction, or a decision briefing — prefer the cktk `interact-html` skill over
plain terminal questions: it renders the interaction as a local HTML page,
collects my answers, and archives the resolved page under .ai/interactions/.
Skip it for trivial yes/no confirmations.
```

## Safety rules

- Write only under `.ai/interactions/`, plus at most one `.gitignore` line in the invoking project. Never commit. Never touch other repo files.
- The page makes no external network requests; its only endpoint is 127.0.0.1 on the one-shot port. Pages may echo project details — treat them as local-only, like `.ai/handoffs/`.
- Never fabricate answers. If both channels fail, ask the questions in the terminal instead.
- Skip this skill for trivial yes/no confirmations — a terminal question is faster.
