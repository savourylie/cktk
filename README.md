# cktk

Software development and UI design workflow skills for OpenAI Codex, Claude Code, and Antigravity.

cktk ships these workflows as **skills** — Markdown files with frontmatter that the host agent (Claude Code, Codex, or Antigravity) loads on demand. There is no runtime, no build step, and no dependency to install: cloning or installing the plugin makes the skill set discoverable to your agent of choice.

## Compatibility Layout

This repo intentionally carries three skill trees:

- `skills/` is the Claude-facing tree (canonical).
- `.agents/skills/` is the Codex-facing tree.
- `.agent/skills/` is the Antigravity-facing tree.

The Claude and Codex trees share support files where possible, but they do not share `SKILL.md` files. The Codex skills are rewritten to match Codex conventions and metadata. The Antigravity tree uses symlinks directly to `skills/`.

## Skills

### Development Skills

- `create-tickets` — generate dev tickets from a PRD, a features catalog, or a Plan Mode plan (plus optional design/UX/reference documents) into `docs/tickets/` with dependency ordering and an INDEX.md tracker
- `implement-ticket` — implement a specific ticket from `docs/tickets/`, run code review, and provide manual testing instructions
- `review-ticket` — review uncommitted changes, branch diffs, PR diffs, or ticket implementations for bugs and scope gaps
- `update-ticket` — change a ticket status, check matching `.worktrees/` implementations, cascade dependency markers, refresh `docs/tickets/INDEX.md`, and commit the doc updates
- `commit-ticket` — create a single git commit from the intended repo changes
- `commit-push-pr` — create one commit, push the branch, and open a pull request
- `create-worktree` — create git worktrees for one or more tickets under `.worktrees/NNN-slug/`, each on its own branch off a chosen base
- `merge-worktree` — merge ticket worktree branches back into their base, then remove the worktree and delete the local branch (cleanup half of `create-worktree`)
- `feature-catalog` — explore a codebase and produce a user-facing feature catalog
- `cktk-upgrade` — pull the latest cktk skills from GitHub and reconcile Claude Code, Codex, Antigravity, and handoff helper installs
- `codex-handoff` — export the latest Claude Code session and git state into a local bundle so Codex can take over
- `grok-handoff` — export the current task (git state, optional Claude session, and agent summary) into a local bundle so Grok Build can take over from any coding agent
- `takeover` — find a pending local handoff, summarize the previous agent's state, and continue the task safely
- `readme-builder` — generate or refresh `README.md` from observed facts (framework, scripts, env vars, existing docs) plus optional UI screenshots via Playwright MCP. Pass `no-screenshots` for a pure-text README

### Design Skills

**UI Design** — extract → review → apply workflow for design systems:

- `design-system-extractor` — analyze UI screenshots to reverse-engineer design tokens (colors, typography, spacing, shadows, component patterns) into structured Markdown + JSON
- `design-system-web-applier` — convert design token JSON into web theme files (CSS custom properties, SCSS, Tailwind, React themes, CSS Modules + TypeScript, Vue 3 composables)
- `design-system-mobile-applier` — convert design token JSON into native mobile theme files (iOS SwiftUI/UIKit, Android Compose/XML, Flutter, React Native)

**Accessibility** — automated WCAG compliance auditing:

- `wcag-accessibility-checker` — audit React/Next.js apps for WCAG 2.2 compliance using static code analysis + axe-core runtime testing, producing a structured conformance report

**UX Design** — PRD-to-UX-design and codebase-to-redesign workflows:

- `ux-design` — transform a PRD into a UX design specification using 6 forced designer mindset passes (mental models, IA, affordances, cognitive load, state design, flow integrity) with ASCII wireframes
- `ux-redesign` — audit an existing codebase against its UX spec and PRD, produce a comprehensive audit report, then rewrite the UX spec with improvements

**Cinematic Design** — film-driven design system bundle from a director and a specific film:

- `cinematic-design-system` — generate a cinematic design system bundle (`docs/RESEARCH.md`, `docs/UX_DESIGN.md`, `docs/INFO_ARCHITECTURE.md`, `docs/DESIGN.md`, `docs/preview.html`, `docs/preview-dark.html`) by running a 4-phase film-driven workflow (decisions → storyboard → back-derived design system → preview rendering). Picks a director + film via a start questionnaire, researches them, writes per-page scene theses and signature compositions, then back-derives the shared design system from locked page compositions. Use when the user wants a film-inspired or director-driven design system rather than a PRD-driven UX spec or a screenshot-driven token extraction.

### Image Generation

- `gen-image-codex` — generate images, illustrations, icons, logos, banners, sprites, or textures with OpenAI's gpt-image-2 through the locally installed Codex CLI (billed via the user's ChatGPT subscription — no API key), saving the PNG into the project (default `./images/`). Shells out to `codex exec` with the built-in `$imagegen` tool; also edits an existing image via `--image`. Requires `codex` installed and logged in with ChatGPT
- `gen-image-agy` — generate images, illustrations, icons, logos, banners, sprites, or textures with Google's Nano Banana (Gemini image) model through the locally installed Antigravity CLI (`agy`), billed to the user's Google AI Pro subscription over OAuth (no API key), saving the PNG into the project (default `./images/`). Runs `agy` headless inside a PTY via the bundled `scripts/gen-image.sh`, which forces the real image-generation tool and verifies a genuine raster landed. Requires `agy` installed and a one-time interactive Google login

## Codex Install

Codex discovers repo-local skills from `.agents/skills/` when you launch Codex inside the repo or a child directory.

### Repo-local

If you want these skills available only inside this repository, nothing else is required. Launch Codex from this repo root or from a nested directory and Codex will scan `.agents/skills/`.

If you want to use this skill set from another repo without copying it, symlink the Codex tree into that repo:

```sh
mkdir -p /path/to/target-repo/.agents
ln -s /absolute/path/to/cktk/.agents/skills /path/to/target-repo/.agents/skills
```

### User-global

If you want these skills available across repos, run the all-agent installer from a full cktk checkout:

```sh
bash /absolute/path/to/cktk/scripts/install-all-agent-skills.sh
```

The installer symlinks cktk skill folders into `${CODEX_HOME:-$HOME/.codex}/skills` without replacing unrelated skills. It also reconciles Antigravity global skills and the handoff shell helpers. `$cktk-upgrade` runs this installer automatically after every successful version check.

### Install from GitHub in Codex Desktop

Codex can also install skills directly from this GitHub repo via `$skill-installer`.

After any installer-based install, restart Codex if the new skills do not appear immediately.

`codex-handoff`, `grok-handoff`, and `takeover` are not compatible with archive-based or sparse-checkout `$skill-installer` installation because their Codex folders use repository-relative symlinks to shared scripts under `skills/`. Install those three through the repo-local or user-global full-tree symlink methods above.

#### Install all skills

Use one installer request with all twenty installer-compatible skill paths:

```text
$skill-installer install from https://github.com/savourylie/cktk with these paths:
.agents/skills/create-tickets
.agents/skills/commit-ticket
.agents/skills/commit-push-pr
.agents/skills/create-worktree
.agents/skills/merge-worktree
.agents/skills/feature-catalog
.agents/skills/implement-ticket
.agents/skills/review-ticket
.agents/skills/update-ticket
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

#### Install an individual skill

Use the GitHub directory URL for the specific skill you want:

```text
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/create-tickets
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/commit-ticket
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/commit-push-pr
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/create-worktree
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/merge-worktree
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/feature-catalog
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/implement-ticket
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/review-ticket
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/update-ticket
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/cktk-upgrade
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/readme-builder
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/design-system-extractor
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/design-system-web-applier
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/design-system-mobile-applier
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/wcag-accessibility-checker
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/ux-design
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/ux-redesign
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/cinematic-design-system
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/gen-image-codex
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/gen-image-agy
```

## Codex Usage

Prefer explicit skill invocation for deterministic behavior:

```text
$create-tickets PRD:docs/PRD.md DESIGN:docs/DESIGN.md
$create-tickets PRD:docs/PRD.md DESIGN:https://api.anthropic.com/v1/design/h/abc123
$create-tickets PRD:docs/PRD.md DESIGN:system-design/
$create-tickets FEATURES:docs/FEATURES.md
$create-tickets PLAN
$create-tickets PLAN:~/.claude/plans/022-agile-candy.md
$implement-ticket TICKET-003
$implement-ticket TICKET-003 worktree
$implement-ticket TICKET-003 worktree dev
$review-ticket
$review-ticket main
$review-ticket --pr 42
$update-ticket TICKET-003 done
$commit-ticket
$commit-push-pr
$create-worktree 7
$create-worktree 7 8 9 dev
$merge-worktree 7
$merge-worktree 7 8 dev
$feature-catalog
$cktk-upgrade
$codex-handoff   # Explains that this is unnecessary inside Codex
$grok-handoff    # Export a local bundle so Grok Build can take over
$takeover
$readme-builder
$readme-builder no-screenshots
$design-system-extractor
$design-system-web-applier tokens.json
$design-system-mobile-applier tokens.json
$wcag-accessibility-checker
$ux-design
$ux-redesign
$cinematic-design-system
$gen-image-codex a dark-mode dashboard banner
$gen-image-agy a photorealistic red apple on a wooden table
```

`review-ticket`, `feature-catalog`, `design-system-extractor`, `design-system-web-applier`, `design-system-mobile-applier`, and `wcag-accessibility-checker` also include descriptions suitable for Codex's implicit skill matching. The write-heavy, handoff, and external-service workflows (`create-tickets`, `implement-ticket`, `update-ticket`, `commit-ticket`, `commit-push-pr`, `create-worktree`, `merge-worktree`, `codex-handoff`, `grok-handoff`, `takeover`, `ux-design`, `ux-redesign`, `readme-builder`, `gen-image-codex`, `gen-image-agy`) remain explicit-only in their `agents/openai.yaml` policy.

## Claude Code Install

```text
/plugin marketplace add savourylie/cktk
/plugin install cktk@savourylie
```

## Claude Code Usage

```text
/create-tickets PRD:docs/PRD.md    # Generate tickets from a PRD
/create-tickets PRD:docs/PRD.md DESIGN:docs/DESIGN.md UX:docs/UX.md
/create-tickets PRD:docs/PRD.md DESIGN:https://api.anthropic.com/v1/design/h/abc123   # Claude Design URL
/create-tickets PRD:docs/PRD.md DESIGN:system-design/   # Claude Design handoff bundle folder
/create-tickets PRD:docs/PRD.md DESIGN:docs/mockups.pdf UX:docs/flows.pptx
/create-tickets FEATURES:docs/FEATURES.md   # Append new features to existing project
/create-tickets PLAN               # Break the current Plan Mode plan into tickets
/create-tickets PLAN:~/.claude/plans/022-agile-candy.md   # Ticket a saved plan file
/create-tickets                    # Auto-detects PRD in docs/tickets/

/implement-ticket 003              # Implement a specific ticket
/implement-ticket TICKET-003       # Also accepts full ticket ID
/implement-ticket 003 worktree     # Implement inside .worktrees/003-slug off origin/main
/implement-ticket 003 worktree dev # Same, but worktree is based on origin/dev

/review-ticket                     # Auto-detect: uncommitted or branch diff
/review-ticket main                # Compare HEAD against main
/review-ticket --pr 42             # Review a pull request
/review-ticket 42                  # Review against ticket #42

/update-ticket TICKET-003 done     # Mark done; checks .worktrees/003-slug if present
/update-ticket 5 in-progress       # Update ticket status

/commit-ticket                     # Commit current changes
/commit-push-pr                    # Commit, push, and open a PR

/create-worktree 7                 # Worktree for ticket 007 off origin/main
/create-worktree 7 8 9             # Worktrees for several tickets at once
/create-worktree 7 dev             # Worktree based on origin/dev instead

/merge-worktree 7                  # Merge ticket 007 into main, remove worktree, delete branch
/merge-worktree 7 8 dev            # Merge multiple tickets into dev and clean up

/feature-catalog                   # Generate feature catalog for current project

/cktk-upgrade                      # Upgrade cktk to latest version from GitHub
/codex-handoff                     # Prepare a local bundle for Codex takeover
/grok-handoff                      # Prepare a local bundle for Grok Build takeover
/takeover                          # Continue a pending handoff from another agent

/design-system-extractor           # Extract tokens from UI screenshots
/design-system-web-applier         # Generate web theme files from tokens
/design-system-mobile-applier      # Generate mobile theme files from tokens
/wcag-accessibility-checker        # Run WCAG accessibility audit
/ux-design                         # Generate UX spec from PRD
/ux-redesign                       # Audit and redesign UX spec
/cinematic-design-system           # Film-driven design system bundle (4 docs + 2 HTML previews)

/readme-builder                    # Generate or refresh README.md from codebase facts + screenshots
/readme-builder no-screenshots     # Same, but skip Playwright screenshot capture

/gen-image-codex a hero banner for a fintech landing page   # PNG into ./images/ via gpt-image-2
/gen-image-agy a photorealistic red apple on a wooden table # PNG into ./images/ via Nano Banana (agy, AI Pro)
```

## Agent Handoff

Handoff bundles let one coding agent continue work left by another without manually locating local transcript files. Supported export paths:

- **Claude Code → Codex** via `codex-handoff`
- **Any coding agent → Grok Build** via `grok-handoff` (git snapshot + agent summary; optionally attaches a Claude Code transcript when present)
- **Generic takeover** via `takeover` in the receiving agent

Bundles are written beneath `.ai/handoffs/` and remain entirely local. They may contain Claude Code transcripts, agent summaries, tool output, file paths, command output, and git diffs, including secrets accidentally printed during the source session. Add this directory to every participating project's `.gitignore`:

```gitignore
.ai/handoffs/
```

Do not upload or commit generated handoff bundles.

### One-time setup (shell helpers)

Install shell helpers once so you can still export when the source agent is rate-limited or unresponsive. From a full cktk checkout:

```bash
bash /absolute/path/to/cktk/scripts/install-all-agent-skills.sh
```

That adds `codex-handoff`, `grok-handoff`, and `cktk-takeover` under `~/.local/bin`, and also reconciles global Codex / Antigravity skill links. `$cktk-upgrade` and `/cktk-upgrade` run this setup automatically after a successful version check.

If `~/.local/bin` is not on your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Without installing helpers, you can still run the scripts by absolute path from a cktk checkout:

```bash
bash /absolute/path/to/cktk/skills/codex-handoff/scripts/codex-handoff.sh
bash /absolute/path/to/cktk/skills/grok-handoff/scripts/grok-handoff.sh --source claude
```

### Claude Code → Codex

#### When Claude Code is still responsive

1. In Claude Code, from the project repo:

   ```text
   /codex-handoff
   ```

2. Open Codex in the **same repository**.

3. In Codex:

   ```text
   $takeover
   ```

#### When Claude Code has hit a rate / usage / context limit

You cannot run `/codex-handoff` inside Claude. Export from the terminal instead:

1. Make sure shell helpers are installed (see [One-time setup](#one-time-setup-shell-helpers)).

2. From the project repo:

   ```bash
   cd /path/to/project
   codex-handoff
   ```

   This requires a Claude Code session on disk for the repo (`~/.claude/projects/...`). It writes a bundle under `.ai/handoffs/codex/` and prints the absolute path.

3. Open Codex in the **same repository**.

4. In Codex:

   ```text
   $takeover
   ```

### Any agent → Grok Build

#### When the source agent is still responsive

1. In the source agent, invoke the skill (it should write an agent summary, then run the exporter):

   ```text
   /grok-handoff
   ```

   In Codex:

   ```text
   $grok-handoff
   ```

2. Open Grok Build in the **same repository**.

3. In Grok Build:

   ```text
   /takeover
   ```

#### When Claude Code (or another source agent) has hit a rate / usage / context limit

You cannot run `/grok-handoff` inside the blocked agent. Export from the terminal instead:

1. Make sure shell helpers are installed (see [One-time setup](#one-time-setup-shell-helpers)).

2. From the project repo:

   ```bash
   cd /path/to/project
   grok-handoff --source claude
   ```

   By default this:

   - Snapshots git status, diffs, log, and untracked files
   - Auto-attaches the latest Claude Code session for the repo when one exists
   - Writes a bundle under `.ai/handoffs/grok/` and prints the absolute path

   Useful variants:

   ```bash
   # Fail if no Claude Code session is found
   grok-handoff --source claude --require-session

   # Git-only (no transcript)
   grok-handoff --source claude --no-session

   # Attach your own continuation notes (recommended if you can write them)
   grok-handoff --source claude --summary /tmp/agent-summary.md
   ```

3. Open Grok Build in the **same repository**.

4. In Grok Build:

   ```text
   /takeover
   ```

### After takeover

In the receiving agent, `$takeover` / `/takeover`:

1. Locates the newest pending (or in-progress) handoff under `.ai/handoffs/`
2. Reads `TAKEOVER.md`, optional `agent-summary.md`, git snapshot, and optional session tail
3. Summarizes prior work and risks before editing
4. Marks the handoff in progress, continues the task, and marks it done only after the work is complete and verified

## Antigravity Install

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
for s in create-tickets implement-ticket review-ticket update-ticket commit-ticket commit-push-pr create-worktree merge-worktree feature-catalog cktk-upgrade codex-handoff grok-handoff takeover readme-builder design-system-extractor design-system-web-applier design-system-mobile-applier wcag-accessibility-checker ux-design ux-redesign cinematic-design-system gen-image-codex gen-image-agy; do
  cp -r /tmp/skills/$s .agent/skills/
done
rm -rf /tmp/skills
```

For user-global Antigravity skills from a full cktk checkout, run:

```bash
bash /absolute/path/to/cktk/scripts/install-all-agent-skills.sh
```

## Supported Platforms

### Web (via design-system-web-applier)

- CSS custom properties
- SCSS variables
- Tailwind CSS config
- React (styled-components, Emotion, Chakra UI)
- CSS Modules + TypeScript
- Vue 3 composables

### Mobile (via design-system-mobile-applier)

- iOS — SwiftUI extensions, UIKit constants
- Android — Jetpack Compose (MaterialTheme), XML resources
- Flutter — ThemeData
- React Native — theme.ts

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

See [`AGENTS.md`](AGENTS.md) for the three-tree maintenance rules: every skill in `skills/` must have a matching folder under `.agents/skills/` and a symlink under `.agent/skills/`. After adding or renaming a skill, update all three trees plus `catalog.json` and `README.md`, then run the validation script.

## Validation

Run the Codex-tree validation script after changing the skill layout:

```sh
./scripts/check-codex-skills.sh
```

## License

TODO: no LICENSE file is present in the repository. Add a license file (MIT, Apache-2.0, etc.) and update this section to declare it.
