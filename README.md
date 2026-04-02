# cktk

Software development and UI design workflow skills for OpenAI Codex, Claude Code, and Antigravity.

## Compatibility Layout

This repo intentionally carries three skill trees:

- `skills/` is the Claude-facing tree (canonical).
- `.agents/skills/` is the Codex-facing tree.
- `.agent/skills/` is the Antigravity-facing tree.

The Claude and Codex trees share support files where possible, but they do not share `SKILL.md` files. The Codex skills are rewritten to match Codex conventions and metadata. The Antigravity tree uses symlinks directly to `skills/`.

## Skills

### Development Skills

- `create-tickets` — generate dev tickets from a PRD and optional design/UX/reference documents into `docs/tickets/` with dependency ordering and an INDEX.md tracker
- `implement-ticket` — implement a specific ticket from `docs/tickets/`, run code review, and provide manual testing instructions
- `review-ticket` — review uncommitted changes, branch diffs, PR diffs, or ticket implementations for bugs and scope gaps
- `update-ticket` — change a ticket status, cascade dependency markers, refresh `docs/tickets/INDEX.md`, and commit the doc updates
- `commit-ticket` — create a single git commit from the intended repo changes
- `commit-push-pr` — create one commit, push the branch, and open a pull request
- `feature-catalog` — explore a codebase and produce a user-facing feature catalog
- `cktk-upgrade` — pull the latest cktk skills from GitHub and update the local installation

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

If you want these skills available across repos, install them under `$HOME/.agents/skills`:

```sh
mkdir -p "$HOME/.agents"
ln -s /absolute/path/to/cktk/.agents/skills "$HOME/.agents/skills"
```

If you already have other global Codex skills, symlink individual skill folders instead of replacing the whole directory.

### Install from GitHub in Codex Desktop

Codex can also install skills directly from this GitHub repo via `$skill-installer`.

After any installer-based install, restart Codex if the new skills do not appear immediately.

#### Install all skills

Use one installer request with all fourteen skill paths:

```text
$skill-installer install from https://github.com/savourylie/cktk with these paths:
.agents/skills/create-tickets
.agents/skills/commit-ticket
.agents/skills/commit-push-pr
.agents/skills/feature-catalog
.agents/skills/implement-ticket
.agents/skills/review-ticket
.agents/skills/update-ticket
.agents/skills/cktk-upgrade
.agents/skills/design-system-extractor
.agents/skills/design-system-web-applier
.agents/skills/design-system-mobile-applier
.agents/skills/wcag-accessibility-checker
.agents/skills/ux-design
.agents/skills/ux-redesign
```

#### Install an individual skill

Use the GitHub directory URL for the specific skill you want:

```text
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/create-tickets
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/commit-ticket
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/commit-push-pr
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/feature-catalog
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/implement-ticket
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/review-ticket
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/update-ticket
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/cktk-upgrade
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/design-system-extractor
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/design-system-web-applier
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/design-system-mobile-applier
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/wcag-accessibility-checker
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/ux-design
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/ux-redesign
```

## Codex Usage

Prefer explicit skill invocation for deterministic behavior:

```text
$create-tickets PRD:docs/PRD.md DESIGN:docs/DESIGN.md
$implement-ticket TICKET-003
$review-ticket
$review-ticket main
$review-ticket --pr 42
$update-ticket TICKET-003 done
$commit-ticket
$commit-push-pr
$feature-catalog
$cktk-upgrade
$design-system-extractor
$design-system-web-applier tokens.json
$design-system-mobile-applier tokens.json
$wcag-accessibility-checker
$ux-design
$ux-redesign
```

`review-ticket`, `feature-catalog`, `design-system-extractor`, `design-system-web-applier`, `design-system-mobile-applier`, and `wcag-accessibility-checker` also include descriptions suitable for Codex's implicit skill matching. The write-heavy workflows (`create-tickets`, `implement-ticket`, `update-ticket`, `commit-ticket`, `commit-push-pr`, `ux-design`, `ux-redesign`) remain explicit-only in their `agents/openai.yaml` policy.

## Claude Code Install

```text
/plugin marketplace add savourylie/cktk
/plugin install cktk@savourylie
```

## Claude Code Usage

```text
/create-tickets PRD:docs/PRD.md    # Generate tickets from a PRD
/create-tickets PRD:docs/PRD.md DESIGN:docs/DESIGN.md UX:docs/UX.md
/create-tickets                    # Auto-detects PRD in docs/tickets/

/implement-ticket 003              # Implement a specific ticket
/implement-ticket TICKET-003       # Also accepts full ticket ID

/review-ticket                     # Auto-detect: uncommitted or branch diff
/review-ticket main                # Compare HEAD against main
/review-ticket --pr 42             # Review a pull request
/review-ticket 42                  # Review against ticket #42

/update-ticket TICKET-003 done     # Mark a ticket as done
/update-ticket 5 in-progress       # Update ticket status

/commit-ticket                     # Commit current changes
/commit-push-pr                    # Commit, push, and open a PR

/feature-catalog                   # Generate feature catalog for current project

/cktk-upgrade                      # Upgrade cktk to latest version from GitHub

/design-system-extractor           # Extract tokens from UI screenshots
/design-system-web-applier         # Generate web theme files from tokens
/design-system-mobile-applier      # Generate mobile theme files from tokens
/wcag-accessibility-checker        # Run WCAG accessibility audit
/ux-design                         # Generate UX spec from PRD
/ux-redesign                       # Audit and redesign UX spec
```

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
for s in create-tickets implement-ticket review-ticket update-ticket commit-ticket commit-push-pr feature-catalog cktk-upgrade design-system-extractor design-system-web-applier design-system-mobile-applier wcag-accessibility-checker ux-design ux-redesign; do
  cp -r /tmp/skills/$s .agent/skills/
done
rm -rf /tmp/skills
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

## Validation

Run the Codex-tree validation script after changing the skill layout:

```sh
./scripts/check-codex-skills.sh
```
