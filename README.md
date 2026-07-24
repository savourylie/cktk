# cktk

Software development and UI design workflow skills for OpenAI Codex, Claude Code, Antigravity, and OpenCode.

cktk ships these workflows as **skills** — Markdown files with frontmatter that the host agent loads on demand. There is no runtime or build step: cloning or installing the skill set makes it discoverable to your agent of choice.

**Contents**

- [Compatibility Layout](#compatibility-layout)
- [Skills](#skills)
- [Install](#install)
- [Usage](#usage)
- [Agent Handoff](#agent-handoff)
- [Supported Platforms](#supported-platforms) · [Token Schema](#token-schema) · [Project Structure](#project-structure)
- [Contributing](#contributing) · [Validation](#validation) · [License](#license)

## Compatibility Layout

This repo intentionally carries three skill trees:

- `skills/` is the Claude-facing tree (canonical).
- `.agents/skills/` is the Codex-facing tree and the repo-local OpenCode-compatible tree.
- `.agent/skills/` is the Antigravity-facing tree.

The Claude and Codex trees share support files where possible, but they do not share `SKILL.md` files. The Codex skills are rewritten to match Codex conventions and use host-neutral workflow language so OpenCode can load them from `.agents/skills/`. The Antigravity tree uses symlinks directly to `skills/`. The all-agent installer also links the canonical skills under OpenCode's global config directory, where repo-local `.agents/skills/` definitions take precedence.

## Skills

Ticket skills come in twins: the plain skill works against `docs/tickets/` markdown files, and the `-linear` twin works against Linear issues (via Linear MCP) without touching `docs/tickets/`.

### Tickets and planning

| Skill(s) | What it does | Notes |
|---|---|---|
| `create-tickets` | Generate dev tickets into `docs/tickets/` from a PRD, a features catalog, or a Plan Mode plan (plus optional design/UX/reference documents), with dependency ordering and an INDEX.md tracker | |
| `clarify-ticket` · `clarify-ticket-linear` | Interactively clarify a ticket's details, blind spots, and risks against the codebase before implementation | Read-only: never edits tickets, INDEX.md, Linear, or git |
| `implement-ticket` · `implement-ticket-linear` | Implement a ticket end to end with code review and manual testing instructions; optional `worktree` keyword for isolated parallel work | docs twin appends as-built notes to the ticket file; the Linear twin's only Linear write is an opt-in as-built comment posted after explicit confirmation |
| `review-ticket` | Review uncommitted changes, branch diffs, PR diffs, single commits, or ticket/Linear-issue implementations for bugs and scope gaps | Linear issue mode requires Linear MCP |
| `update-ticket` · `update-ticket-linear` | Change a ticket/issue status, check matching worktree implementations, and cascade dependency/blocked markers | docs twin refreshes INDEX.md and commits the doc update; Linear twin evaluates acceptance criteria first and creates no git commit |
| `quiz-ticket` · `quiz-ticket-linear` | Quiz your understanding of an implemented ticket from its implementation diff, or produce a stakeholder explainer with `explain` | Read-only against the repo and Linear |

### Git workflow

| Skill(s) | What it does | Notes |
|---|---|---|
| `commit-ticket` | Create a single git commit from the intended repo changes | |
| `commit-push-pr` | Create one commit, push the branch, and open a pull request | |
| `create-worktree` | Create git worktrees for one or more tickets under `.worktrees/NNN-slug/`, each on its own branch off a chosen base | |
| `merge-worktree` | Merge ticket worktree branches back into their base, then remove the worktree and delete the local branch | Cleanup half of `create-worktree` |

### Agent handoff

| Skill(s) | What it does | Notes |
|---|---|---|
| `codex-handoff` | Export the latest Claude Code session and git state into a local bundle so Codex can take over | See [Agent Handoff](#agent-handoff) |
| `grok-handoff` | Export the current task (git state, optional Claude session, agent summary) so Grok Build can take over from any coding agent | See [Agent Handoff](#agent-handoff) |
| `opencode-handoff` | Export the current task (git state, optional Claude session, agent summary) so OpenCode can take over from any coding agent | See [Agent Handoff](#agent-handoff) |
| `takeover` | Find a pending local handoff, summarize the previous agent's state, and continue the task safely | Run in the receiving agent |

### Docs and maintenance

| Skill(s) | What it does | Notes |
|---|---|---|
| `feature-catalog` | Explore a codebase and produce a user-facing feature catalog | |
| `readme-builder` | Generate or refresh `README.md` from observed facts (framework, scripts, env vars, existing docs) plus optional UI screenshots via Playwright MCP | Pass `no-screenshots` for a pure-text README |
| `cktk-upgrade` | Pull the latest cktk skills from GitHub and reconcile Claude Code, Codex, Antigravity, and handoff helper installs | |

### Design and UX

| Skill(s) | What it does | Notes |
|---|---|---|
| `design-system-extractor` | Analyze UI screenshots to reverse-engineer design tokens (colors, typography, spacing, shadows, component patterns) into structured Markdown + JSON | Extract step of the extract → review → apply workflow |
| `design-system-web-applier` | Convert design token JSON into web theme files (CSS custom properties, SCSS, Tailwind, React themes, CSS Modules + TypeScript, Vue 3 composables) | |
| `design-system-mobile-applier` | Convert design token JSON into native mobile theme files (iOS SwiftUI/UIKit, Android Compose/XML, Flutter, React Native) | |
| `wcag-accessibility-checker` | Audit React/Next.js apps for WCAG 2.2 compliance using static code analysis + axe-core runtime testing, producing a structured conformance report | |
| `ux-design` | Transform a PRD into a UX design specification using 6 forced designer mindset passes, with ASCII wireframes | |
| `ux-redesign` | Audit an existing codebase against its UX spec and PRD, produce an audit report, then rewrite the UX spec with improvements | |
| `cinematic-design-system` | Generate a film-driven design system bundle (4 Markdown docs + 2 HTML previews) via a 4-phase director + film workflow that back-derives the design system from locked page compositions | Use when the brief is film-inspired rather than PRD- or screenshot-driven |

### Image generation

| Skill(s) | What it does | Notes |
|---|---|---|
| `gen-image-codex` | Generate or edit images (icons, logos, banners, sprites, textures) with OpenAI's gpt-image-2 via the local Codex CLI, saving PNGs into `./images/` | Billed via ChatGPT subscription, no API key; requires `codex` installed and logged in |
| `gen-image-agy` | Generate images with Google's Nano Banana (Gemini image) model via the local Antigravity CLI (`agy`) run headless in a PTY, saving PNGs into `./images/` | Billed to Google AI Pro over OAuth, no API key; requires `agy` and a one-time Google login |

## Install

Pick your agent:

### Claude Code

```text
/plugin marketplace add savourylie/cktk
/plugin install cktk@savourylie
```

### Codex (repo-local)

Codex discovers repo-local skills from `.agents/skills/` when you launch Codex inside the repo or a child directory — clone this repo and nothing else is required.

To use this skill set from another repo without copying it, symlink the Codex tree into that repo:

```sh
mkdir -p /path/to/target-repo/.agents
ln -s /absolute/path/to/cktk/.agents/skills /path/to/target-repo/.agents/skills
```

### Codex (user-global)

To make the skills available across repos, run the all-agent installer from a full cktk checkout:

```sh
bash /absolute/path/to/cktk/scripts/install-all-agent-skills.sh
```

The installer symlinks cktk skill folders into `${CODEX_HOME:-$HOME/.codex}/skills` without replacing unrelated skills. It also reconciles Antigravity global skills and the handoff shell helpers. `$cktk-upgrade` runs this installer automatically after every successful version check.

### Codex ($skill-installer)

Codex Desktop can also install skills directly from this GitHub repo via `$skill-installer`. After any installer-based install, restart Codex if the new skills do not appear immediately.

`codex-handoff`, `grok-handoff`, `opencode-handoff`, and `takeover` are not compatible with archive-based or sparse-checkout `$skill-installer` installation because their Codex folders use repository-relative symlinks to shared scripts under `skills/`. Install those four through the repo-local or user-global full-tree symlink methods above.

To install everything, use one installer request listing every installer-compatible skill path (all skills except the four handoff skills):

```text
$skill-installer install from https://github.com/savourylie/cktk with these paths:
.agents/skills/create-tickets
.agents/skills/commit-ticket
.agents/skills/commit-push-pr
.agents/skills/create-worktree
.agents/skills/merge-worktree
.agents/skills/feature-catalog
.agents/skills/implement-ticket
.agents/skills/clarify-ticket
.agents/skills/clarify-ticket-linear
.agents/skills/implement-ticket-linear
.agents/skills/review-ticket
.agents/skills/update-ticket
.agents/skills/update-ticket-linear
.agents/skills/quiz-ticket
.agents/skills/quiz-ticket-linear
.agents/skills/cktk-upgrade
.agents/skills/readme-builder
.agents/skills/design-system-extractor
.agents/skills/design-system-web-applier
.agents/skills/design-system-mobile-applier
.agents/skills/wcag-accessibility-checker
.agents/skills/ux-design
.agents/skills/ux-redesign
.agents/skills/cinematic-design-system
.agents/skills/gen-image-codex
.agents/skills/gen-image-agy
```

To install a single skill, use its GitHub directory URL — `https://github.com/savourylie/cktk/tree/main/.agents/skills/<skill-name>` with any path from the list above, for example:

```text
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/create-tickets
```

### Antigravity

Clone the repo into your project or add it as a submodule — skills are discovered automatically from `.agent/skills/`:

```bash
git clone https://github.com/savourylie/cktk.git .cktk
# or
git submodule add https://github.com/savourylie/cktk.git .cktk
```

Or install skills directly from GitHub:

```bash
curl -sL https://github.com/savourylie/cktk/archive/refs/heads/main.tar.gz \
  | tar xz --strip-components=1 -C /tmp cktk-main/skills
mkdir -p .agent/skills
for s in create-tickets implement-ticket clarify-ticket clarify-ticket-linear implement-ticket-linear review-ticket update-ticket update-ticket-linear quiz-ticket quiz-ticket-linear commit-ticket commit-push-pr create-worktree merge-worktree feature-catalog cktk-upgrade codex-handoff grok-handoff opencode-handoff takeover readme-builder design-system-extractor design-system-web-applier design-system-mobile-applier wcag-accessibility-checker ux-design ux-redesign cinematic-design-system gen-image-codex gen-image-agy; do
  cp -r /tmp/skills/$s .agent/skills/
done
rm -rf /tmp/skills
```

For user-global Antigravity skills from a full cktk checkout, run:

```bash
bash /absolute/path/to/cktk/scripts/install-all-agent-skills.sh
```

### OpenCode

OpenCode discovers the repo-local `.agents/skills/` tree automatically. `scripts/install-all-agent-skills.sh` also links the canonical skills under OpenCode's global config directory, where repo-local `.agents/skills/` definitions take precedence.

## Usage

All commands below use Claude Code's `/name` syntax. In **Codex**, invoke the same skill as `$name` with identical arguments (e.g. `/implement-ticket 003 worktree` → `$implement-ticket 003 worktree`). In **OpenCode**, skills load through the skill mechanism rather than slash commands — name the skill in the request, e.g. "Use clarify-ticket for TICKET-007." or "Use quiz-ticket-linear for ENG-42." In **Antigravity**, skills are discovered from `.agent/skills/` and matched by description.

### Ticket lifecycle

```text
/create-tickets PRD:docs/PRD.md              # Generate tickets from a PRD
/create-tickets PRD:docs/PRD.md DESIGN:docs/DESIGN.md UX:docs/UX.md
/create-tickets PRD:docs/PRD.md DESIGN:https://api.anthropic.com/v1/design/h/abc123   # Claude Design URL; also accepts folders, PDFs, PPTX
/create-tickets FEATURES:docs/FEATURES.md    # Append new features to an existing project
/create-tickets PLAN                         # Break the current Plan Mode plan into tickets (or PLAN:<path> for a saved plan file)
/create-tickets                              # Auto-detects the PRD

/clarify-ticket 007                          # Read ticket, analyze vs. code, discuss risks (read-only)
/clarify-ticket-linear ENG-42                # Same for a Linear issue (requires Linear MCP)

/implement-ticket 003                        # Implement a ticket (also accepts TICKET-003)
/implement-ticket 003 worktree               # Implement inside .worktrees/003-slug off origin/main
/implement-ticket 003 worktree dev           # Same, based on origin/dev (worktree variants also work for implement-ticket-linear)
/implement-ticket-linear ENG-42              # Implement a Linear issue (requires Linear MCP)

/review-ticket                               # Auto-detect: uncommitted changes or branch diff
/review-ticket main                          # Compare HEAD against main
/review-ticket --pr 42                       # Review a pull request
/review-ticket 42                            # Review against ticket #42
/review-ticket ENG-42                        # Review uncommitted changes against a Linear issue
/review-ticket abc1234                       # Review a single commit

/update-ticket TICKET-003 done               # Mark done; checks .worktrees/003-slug if present
/update-ticket-linear ENG-42                 # Auto-eval acceptance criteria; mark Done when safe
/update-ticket-linear ENG-42 in-progress     # Move a Linear issue to In Progress

/quiz-ticket 007                             # Quiz your understanding of an implemented ticket (read-only)
/quiz-ticket 007 explain                     # Stakeholder explainer instead of a quiz
/quiz-ticket-linear ENG-42                   # Same for a Linear issue; `explain` works here too
```

### Git and worktrees

```text
/commit-ticket                     # Commit current changes
/commit-push-pr                    # Commit, push, and open a PR
/create-worktree 7                 # Worktree for ticket 007 off origin/main
/create-worktree 7 8 9 dev         # Several tickets at once, based on origin/dev
/merge-worktree 7                  # Merge ticket 007 back, remove worktree, delete branch (same multi-ticket and base args)
```

### Agent handoff

```text
/codex-handoff                     # Prepare a local bundle for Codex takeover ($codex-handoff explains this is unnecessary inside Codex)
/grok-handoff                      # Prepare a local bundle for Grok Build takeover (in Codex: $grok-handoff)
/opencode-handoff                  # Prepare a local bundle for OpenCode takeover (in Codex: $opencode-handoff)
/takeover                          # Continue a pending handoff from another agent (in Codex: $takeover)
```

### Docs and maintenance

```text
/feature-catalog                   # Generate a feature catalog for the current project
/readme-builder                    # Generate or refresh README.md from codebase facts + screenshots
/readme-builder no-screenshots     # Same, but skip Playwright screenshot capture
/cktk-upgrade                      # Upgrade cktk to the latest version from GitHub
```

### Design and UX

```text
/design-system-extractor                  # Extract tokens from UI screenshots
/design-system-web-applier tokens.json    # Generate web theme files from tokens
/design-system-mobile-applier tokens.json # Generate mobile theme files from tokens
/wcag-accessibility-checker               # Run WCAG accessibility audit
/ux-design                                # Generate UX spec from PRD
/ux-redesign                              # Audit and redesign UX spec
/cinematic-design-system                  # Film-driven design system bundle (4 docs + 2 HTML previews)
```

### Image generation

```text
/gen-image-codex a hero banner for a fintech landing page   # PNG into ./images/ via gpt-image-2
/gen-image-agy a photorealistic red apple on a wooden table # PNG into ./images/ via Nano Banana (agy, AI Pro)
```

Two notes on host behavior:

- **Codex triggering policy:** `review-ticket`, `feature-catalog`, `design-system-extractor`, `design-system-web-applier`, `design-system-mobile-applier`, and `wcag-accessibility-checker` also include descriptions suitable for Codex's implicit skill matching; every other skill (the write-heavy, handoff, and external-service workflows) is explicit-only in its `agents/openai.yaml` policy.
- The clarification and quiz skills use host-neutral questions and follow-up wording. They do not assume Claude's `/skill` syntax, Codex's `$skill` syntax, or a particular structured-choice tool.

## Agent Handoff

Handoff bundles let one coding agent continue work left by another without hunting for local transcript files. `/codex-handoff` (Claude Code → Codex), `/grok-handoff` (any agent → Grok Build), and `/opencode-handoff` (any agent → OpenCode) export the current git state — plus a Claude Code transcript when one exists — into a local bundle. The receiving agent runs `/takeover` to locate the newest pending bundle, summarize prior work and risks, and continue safely. In Codex the same skills are `$takeover`, `$grok-handoff`, and `$opencode-handoff`.

Bundles are written beneath `.ai/handoffs/` and stay entirely local. They may contain transcripts, command output, and git diffs — including secrets accidentally printed during the source session — so add `.ai/handoffs/` to every participating project's `.gitignore` and never commit or upload them.

Installing the shell helpers via `scripts/install-all-agent-skills.sh` lets you export from the terminal even when the source agent is rate-limited or out of context. Full walkthroughs, terminal-export commands, and exporter flags: **[docs/agent-handoff.md](docs/agent-handoff.md)**.

## Supported Platforms

`design-system-web-applier` targets CSS custom properties, SCSS variables, Tailwind CSS config, React (styled-components, Emotion, Chakra UI), CSS Modules + TypeScript, and Vue 3 composables. `design-system-mobile-applier` targets iOS (SwiftUI extensions, UIKit constants), Android (Jetpack Compose MaterialTheme, XML resources), Flutter (ThemeData), and React Native (theme.ts).

## Token Schema

The three design-system skills share a common JSON token format inspired by the W3C Design Tokens Community Group spec:

```json
{
  "meta": {
    "name": "My Design System",
    "source": "Screenshots of example.com",
    "version": "1.0.0",
    "generated": "2025-01-15"
  },
  "color": {
    "primary": { "value": "#2563EB", "type": "color" }
  },
  "typography": {
    "family": { "heading": { "value": "'Inter', sans-serif" } },
    "size": { "base": { "value": "16px" } }
  },
  "spacing": { "4": { "value": "16px" } },
  "borderRadius": { "md": { "value": "8px" } },
  "shadow": { "sm": { "value": "0 1px 2px rgba(0,0,0,0.05)" } },
  "components": { }
}
```

All values use platform-agnostic `px` units. Applier skills convert to the appropriate unit for each target (`rem`, `pt`, `dp`, `sp`, etc.).

See [`skills/design-system-extractor/references/token-schema.md`](skills/design-system-extractor/references/token-schema.md) for the full schema specification.

## Project Structure

These ticket-management skills expect a project to provide:

- `docs/PRD.md` — product requirements document
- `docs/DESIGN.md` — architecture and design document
- `docs/tickets/INDEX.md` — ticket index with status tracking
- `docs/tickets/TICKET-NNN.md` — individual ticket files

The UX design skills expect:

- `docs/PRD.md` — product requirements document
- `docs/FEATURES.md` — structured feature catalog (optional for `ux-design`, required for `ux-redesign`)
- `docs/UX_DESIGN.md` — UX design specification (output of `ux-design`, input for `ux-redesign`)

A PRD template is available at `templates/PRD.md`.

## Contributing

See [`AGENTS.md`](AGENTS.md) for the three-tree maintenance rules: every skill in `skills/` must have a matching folder under `.agents/skills/` and a symlink under `.agent/skills/`. After adding or renaming a skill, update all three trees plus `catalog.json` and `README.md`, then run the validation script. Handoff workflow documentation lives in [`docs/agent-handoff.md`](docs/agent-handoff.md) — update it alongside this README when changing the handoff skills, and note that `scripts/test-handoff-tools.sh` asserts specific strings in `README.md`.

## Validation

Run the cross-agent skill validation script after changing skill content or layout. It checks Claude/Codex parity, exact Antigravity symlinks, OpenAI metadata, and the portable clarification contracts:

```sh
./scripts/check-codex-skills.sh
```

## License

TODO: no LICENSE file is present in the repository. Add a license file (MIT, Apache-2.0, etc.) and update this section to declare it.
