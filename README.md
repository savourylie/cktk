# cktk

Software development and UI design workflow skills for OpenAI Codex, Claude Code, Grok Build, Antigravity, and OpenCode.

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

- `skills/` is the canonical tree, including agent-neutral ticket lifecycle workflows.
- `.agents/skills/` links portable folders to the canonical tree and retains native Codex documents for unmigrated skills.
- `.agent/skills/` is the Antigravity-facing tree.

Skills marked `portable: true` in `catalog.json` share the entire folder, including `SKILL.md`, resources, and optional `agents/openai.yaml`. Unmigrated skills still have distinct Codex instructions and share support resources through symlinks. Antigravity links directly to `skills/`. The installer and doctor keep local agent entries tied to the selected checkout; discovery precedence is checked through the host instead of assumed.

## Skills

Ticket skills come in twins: the plain skill works against `docs/tickets/` markdown files, and the `-linear` twin works against Linear issues (via Linear MCP) without touching `docs/tickets/`.

### Tickets and planning

| Skill(s) | What it does | Notes |
|---|---|---|
| `init-project` | Record where this repository's project lives — Linear team and project, Notion hub and decision log, and the repository paths holding requirements — into a committed `.ai/cktk/project.json` that other skills read | Discovers candidates from README/PRD/design docs before asking; validates every binding against the live services, including a consented write probe; never records an unvalidated binding as confirmed. Re-runnable for single-field corrections |
| `project-advisor` | Assess overall project direction across Notion, Linear, and repo evidence; recommend strategic trade-offs and tactical next steps, discuss alternatives, and revisit earlier decisions | Uses existing `init-project` bindings; continues with available evidence when a source is missing. Advisory by default; saves a dated discussion/decision record on request |
| `create-tickets` | Generate dev tickets into `docs/tickets/` from a PRD, a features catalog, or a Plan Mode plan (plus optional design/UX/reference documents), with dependency ordering and an INDEX.md tracker | |
| `create-tickets-linear` | Create Linear issues from requirements, a feature catalog, or a conversation or saved plan, with acceptance criteria and native dependency relations | Uses explicit destinations or validated project bindings; checks existing coverage and reconciles partial creation before retrying. Requires Linear MCP; preserves existing issues |
| `clarify-ticket` · `clarify-ticket-linear` | Interactively clarify a ticket's details, blind spots, and risks against the codebase before implementation | Read-only: never edits tickets, INDEX.md, Linear, or git |
| `implement-ticket` · `implement-ticket-linear` | Implement a ticket in its project business context, trace direct and indirect ticket relationships, clarify conflicting definitions, and verify the result; supports `worktree` and final `via codex\|claude\|grok` delegation | Default: implementation, review, and summary; further actions follow existing user authorization. Linear Backlog issues are valid inputs. The automatic Todo → In Progress transition occurs only after context and workspace readiness; completion updates use the matching update skill |
| `review-ticket` | Review uncommitted changes, branch diffs, PR diffs, single commits, or ticket/Linear-issue implementations for bugs and scope gaps | Linear issue mode requires Linear MCP |
| `update-ticket` · `update-ticket-linear` | Reconcile status and affected dependencies from business context and acceptance evidence, in the selected checkout | Clear completion moves directly to Done without another confirmation. The docs twin commits only its tracker changes via `commit-ticket`; the Linear twin creates no git commit. Bound Project Context and Notion follow-ups use independent preferences and authorization |
| `quiz-ticket` · `quiz-ticket-linear` | Quiz your understanding of an implemented ticket from its implementation diff, or produce a stakeholder explainer with `explain` | Read-only against the repo and Linear |

### Git workflow

| Skill(s) | What it does | Notes |
|---|---|---|
| `commit-ticket` | Stage intended pending changes and create one documented git commit, for ticket work or ad hoc edits | Includes unstaged changes and relevant new files by default; uses Conventional Commits with an explanatory body for substantive changes. No ticket ID required |
| `commit-push-pr` | Commit when needed, push the intended branch, and create or reuse a GitHub PR | Uses `commit-ticket` for staging and messages; supports already-committed work and retains worktree/head/base context |
| `create-worktree` · `create-worktree-linear` | Create git worktrees for one or more tickets under `.worktrees/NNN-slug/` or Linear issues under `.worktrees/ENG-42-slug/`, each on its own branch off a chosen base | Linear twin requires Linear MCP and makes no Linear writes — not even the Todo → In Progress transition `implement-ticket-linear` performs |
| `merge-worktree` · `merge-worktree-linear` | Merge ticket or Linear issue worktree branches back into their base, then remove the worktree and delete the local branch | Cleanup halves of the two create skills. The Linear twin is the one `-linear` skill that needs no Linear MCP — everything it reads is on disk |

### Agent handoff

| Skill(s) | What it does | Notes |
|---|---|---|
| `codex-handoff` | Export the latest Claude Code session and git state into a local bundle so Codex can take over | See [Agent Handoff](#agent-handoff) |
| `grok-handoff` | Export the current task (git state, optional Claude session, agent summary) so Grok Build can take over from any coding agent | See [Agent Handoff](#agent-handoff) |
| `opencode-handoff` | Export the current task (git state, optional Claude session, agent summary) so OpenCode can take over from any coding agent | See [Agent Handoff](#agent-handoff) |
| `takeover` | Find a pending local handoff, summarize the previous agent's state, and continue the task safely | Run in the receiving agent |

### Agent interaction

| Skill(s) | What it does | Notes |
| --- | --- | --- |
| `clarify` | Explain a previous statement again after the user says they do not understand it — recover the missing context from Linear, Notion, tickets, docs, and code, then re-explain with explicit scope, resolved references, defined terminology, and the missing reasoning steps filled in | Clarifies a *statement*, not a ticket — use `clarify-ticket` for that. Read-only; Linear and Notion MCP are optional and it degrades to repo sources without them |
| `debrief-result` | Explain what a just-delivered result means for the project (typically after `implement-ticket` or `implement-ticket-linear`) | No ticket id — uses the current conversation. Read-only. Not a quiz, not a review, not `clarify` |
| `interact-html` | Render clarifying questions, option picks, and decision briefings as a local interactive HTML page, collect answers via a one-shot localhost server or paste-back, and archive the resolved page as a decision record | Pages live under `.ai/interactions/` (gitignored, local-only) |

### Docs and maintenance

| Skill(s) | What it does | Notes |
|---|---|---|
| `feature-catalog` | Explore a codebase and produce a user-facing feature catalog | |
| `readme-builder` | Generate or refresh `README.md` from observed facts (framework, scripts, env vars, existing docs) plus optional UI screenshots via Playwright MCP | Pass `no-screenshots` for a pure-text README |
| `update-agents` | Persist durable agent instructions into the current repo's `AGENTS.md` and `CLAUDE.md` | Optional argument is the instruction; with no argument, writes what the agent said it would remember next time. Does not commit |
| `cktk-upgrade` | Pull the latest cktk skills from GitHub and reconcile Claude Code, Codex, Antigravity, OpenCode, and handoff helper installs | |

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

### One source across coding agents

The eight ticket lifecycle skills (`create-tickets`, `create-tickets-linear`, both `implement-ticket` variants, `commit-ticket`, `commit-push-pr`, and both `update-ticket` variants) have one agent-neutral source under `skills/`. Their `.agents/skills/` and `.agent/skills/` entries link to those folders. Codex UI metadata stays in `agents/openai.yaml`; workflow instructions are never copied or generated per agent. `catalog.json` marks this set with `portable: true`. Other skills retain their existing native documents until individually reviewed.

For daily use across agents, choose one **full checkout** and link it:

```sh
git clone https://github.com/savourylie/cktk.git /absolute/path/to/cktk
bash /absolute/path/to/cktk/scripts/install-all-agent-skills.sh --mode linked
python3 /absolute/path/to/cktk/scripts/agent-skills.py doctor --runtime
```

Use an existing checkout instead of cloning again when developing these skills. Editing a shared source immediately changes the files every linked agent reads; an already-running session may need to reload its skill registry or start a new session.

| Agent | Linked installation |
| --- | --- |
| Codex | Portable skills in `~/.agents/skills`; remaining native skills in `${CODEX_HOME:-$HOME/.codex}/skills` |
| Claude Code | Personal skills in `~/.claude/skills`, all linked to the selected checkout |
| Grok Build | Shared `~/.agents/skills` and Claude-compatible skill discovery |
| OpenCode | Shared `~/.agents/skills`; remaining skills in `${OPENCODE_HOME:-$HOME/.config/opencode}/skills` |
| Antigravity | `${AGENT_HOME:-$HOME/.agent}/skills` linked to the selected tree |

The installer also reconciles the four handoff shell helpers in `~/.local/bin`. It records the chosen checkout and mode in `~/.local/share/cktk/install.json`, so `$cktk-upgrade` keeps using that source. No background service or file-copy sync is needed. Pass `--project-root /path/to/project` only when you also want the handoff/interactions ignore rules added to that project's `.gitignore`. `--home /temporary/path` gives an isolated installation for testing and ignores agent-home environment overrides.

Existing cktk links can be repointed; identical copies are backed up. An unknown folder or foreign link is a conflict, even when its skill name matches. The installer checks all planned paths before changing them. Preserve and review older unverified copies before replacing them; a name alone is not proof of ownership.

If migrating from the Claude marketplace plugin, first verify the personal skill links, then disable only the old cktk plugin in its installed scope:

```sh
claude plugin list --json
claude plugin disable cktk@cktk --scope user
python3 /absolute/path/to/cktk/scripts/agent-skills.py doctor --runtime
```

Use the actual scope shown by the CLI, and the matching project directory for project/local scope. This preserves the installed plugin for switching back later and prevents Grok's compatibility import from loading an older cktk cache. Other plugins remain enabled. Claude may need `/reload-plugins` after the change.

Claude personal skills use `/skill-name`; plugin mode uses `/cktk:skill-name`. Codex uses `$skill-name`, and Grok/OpenCode can load the named skill through their skill mechanism. Arguments and the eight shared workflows stay the same.

`doctor` reports the registered source, Git revision, dirty state, payload hash, and broken/different/duplicate links. `--runtime` additionally checks enabled Claude plugins and available Grok/OpenCode inventories from the current project. It distinguishes same-source aliases from another cktk version and reports unrelated same-name skills without deleting them. CLI inspection failures remain unverified; filesystem checks cannot prove what an already-running model has loaded. For an unambiguous invocation when another plugin uses the same name, identify cktk and its skill path explicitly.

### Claude marketplace releases

For a Claude-managed release instead of a linked development checkout:

```text
/plugin marketplace add savourylie/cktk
/plugin install cktk@cktk
```

Then reconcile other agents from that marketplace's full checkout with `scripts/install-all-agent-skills.sh --mode plugin`. In this mode Claude owns its cache; the other agents link to the marketplace checkout. `$cktk-upgrade` updates the marketplace and installed plugin scopes through Claude's CLI, reconciles links even when already current, and checks that the plugin payload matches the source. The marketplace uses Git commit versions. Do not edit plugin caches or maintain a separate per-agent release.

### Repository-local discovery and complete payloads

Codex discovers `.agents/skills/` when launched inside this repo. To expose that tree in another repository:

```sh
mkdir -p /path/to/target-repo/.agents
ln -s /absolute/path/to/cktk/.agents/skills /path/to/target-repo/.agents/skills
```

OpenCode and Grok also support shared skills; Claude uses `.claude/skills/`, and Antigravity uses `.agent/skills/`. Global linked installation is usually simpler than maintaining project-specific links. Check the host's current discovery rules when adding another agent: [Codex](https://learn.chatgpt.com/docs/build-skills), [Claude Code](https://code.claude.com/docs/en/skills), [Grok Build](https://docs.x.ai/build/features/skills-plugins-marketplaces), and [OpenCode](https://opencode.ai/docs/skills).

The portable workflows, handoff tools, and binding-aware skills are not compatible with archive-based or sparse single-folder installs: they need shared resources and sibling skill contracts. Keep the full checkout, including `skills/`, `.agents/skills/`, `.agent/skills/`, `catalog.json`, and `scripts/`. Copying only `SKILL.md` can silently lose metadata, delegation scripts, or business-context references.

## Usage

Unless labeled as Codex examples, commands below use Claude Code's `/name` syntax. In **Codex**, invoke the same skill as `$name` with identical arguments (e.g. `/implement-ticket 003 worktree` → `$implement-ticket 003 worktree`). In **OpenCode**, skills load through the skill mechanism rather than slash commands — name the skill in the request, e.g. "Use clarify-ticket for TICKET-007." or "Use quiz-ticket-linear for ENG-42." In **Antigravity**, skills are discovered from `.agent/skills/` and matched by description.

### Project direction and priorities

`project-advisor` connects goals, required capabilities, work allocation, implementation, and verified outcomes. It identifies consequential gaps, recommends what to focus on or defer, and turns that direction into concrete next actions with completion or learning criteria. Follow-up discussion revises the advice as constraints change.

Codex examples (use `/project-advisor` in Claude Code):

```text
$project-advisor
$project-advisor 接下來兩週應該優先做什麼？
$project-advisor 相較上次，有哪些變化值得重新考慮方向？
$project-advisor 把剛才的討論與我採納的決策保存下來
```

The default assessment reads sources and replies in the conversation. It uses `.ai/cktk/project.json` when configured, reports source conflicts and coverage limits, and distinguishes reported ticket completion, implementation, testing, deployment, and observed user outcomes. A request to save creates a dated record under `.ai/cktk/advisor/` in the main checkout unless another destination is specified; it preserves proposed versus adopted decisions and revisit conditions, without staging or committing. Earlier records are refreshed against current sources before their conclusions are reused. With no baseline, it assesses the present and says comparison is unavailable.

`debrief-result` explains one just-delivered result; `project-advisor` evaluates broader direction and priorities. Accepting advice does not automatically create tickets or change Notion/Linear. An explicit execution request carries the chosen decision into the relevant execution workflow.

### Ticket lifecycle

```text
/init-project                                # Bind this repo to its Linear project and Notion workspace
/init-project notion                         # Re-validate and correct just the Notion bindings
/init-project --show                         # Print the current bindings and their statuses

/create-tickets PRD: docs/PRD.md              # Create tickets, or append to an existing backlog
/create-tickets PRD:docs/PRD.md DESIGN: system-design/ UX: docs/UX.md
/create-tickets FEATURES: docs/FEATURES.md    # Ticket only work not already implemented or ticketed
/create-tickets PLAN                         # Use the plan identified in this conversation
/create-tickets PLAN: "docs/plans/account recovery.md"
/create-tickets append tickets for the recovery flow from docs/PRD.md
/create-tickets                              # Discover the PRD when no source is supplied

/create-tickets-linear PRD: docs/PRD.md TEAM: ENG PROJECT: "Account Platform"
/create-tickets-linear FEATURES: docs/FEATURES.md  # Use the bound Linear destination
/create-tickets-linear PLAN                       # Create issues from this conversation's plan

/clarify-ticket 007                          # Read ticket, analyze vs. code, discuss risks (read-only)
/clarify-ticket-linear ENG-42                # Same for a Linear issue (requires Linear MCP)

/implement-ticket 003                        # Implement on branch ticket-003-slug off the current HEAD
/implement-ticket 003 dev                    # Same, but branch off origin/dev
/implement-ticket 003 worktree               # Implement inside .worktrees/003-slug off origin/main
/implement-ticket 003 worktree dev           # Same, based on origin/dev (all variants also work for implement-ticket-linear)
/implement-ticket 003 worktree via claude    # Delegate implementation only to Claude Code CLI
/implement-ticket 003 via codex               # Delegate implementation only to Codex CLI
/implement-ticket 003 dev via grok            # Delegate implementation only to Grok Build CLI, branching from dev
/implement-ticket-linear ENG-42              # Implement a Linear issue (requires Linear MCP)
/implement-ticket-linear ENG-42 worktree     # Backlog issues are valid; isolated checkout off main
/implement-ticket-linear ENG-42 worktree dev # Isolated checkout off dev
/implement-ticket-linear ENG-42 via codex    # Same delegation clause for a Linear issue

/review-ticket                               # Auto-detect: uncommitted changes or branch diff
/review-ticket main                          # Compare HEAD against main
/review-ticket --pr 42                       # Review a pull request
/review-ticket 42                            # Review against ticket #42
/review-ticket ENG-42                        # Review uncommitted changes against a Linear issue
/review-ticket --ticket TAI-90 --base main    # Review committed HEAD vs main against a Linear issue
/review-ticket --ticket TAI-90                # Same, resolving the default main/master base
/review-ticket abc1234                       # Review a single commit

/update-ticket TICKET-003 done               # Verify completion and commit scoped tracker changes
/update-ticket-linear ENG-42                 # Mark Done directly when the outcome is established
/update-ticket-linear ENG-42 in-progress     # Move a Linear issue to In Progress

/quiz-ticket 007                             # Quiz your understanding of an implemented ticket (read-only)
/quiz-ticket 007 explain                     # Stakeholder explainer instead of a quiz
/quiz-ticket-linear ENG-42                   # Same for a Linear issue; `explain` works here too
```

For Codex, invoke ticket creation explicitly:

```text
$create-tickets PRD: docs/PRD.md DESIGN: system-design/
$create-tickets FEATURES:docs/FEATURES.md
$create-tickets PLAN
$create-tickets append tickets for the recovery flow from docs/PRD.md

$create-tickets-linear PRD: docs/PRD.md TEAM: ENG PROJECT: "Account Platform"
$create-tickets-linear FEATURES:docs/FEATURES.md
$create-tickets-linear PLAN
$create-tickets-linear draft recovery-flow issues for the bound Linear project
```

`create-tickets` accepts natural language, `KEY:value` and `KEY: value`, and quoted paths with spaces. PRDs, catalogs, and plans can seed a new tracker or extend an existing one. Existing tickets are preserved by default; replacement requires authorization. Ticket boundaries follow coherent, verifiable outcomes. Separate checkpoints are added where integration, risk, or user acceptance warrants a gate.

`create-tickets-linear` uses the same breakdown principles, with Linear-assigned identifiers, team workflow states, and native blocking relations. Explicit team/project choices take precedence over compatible validated `.ai/cktk/project.json` bindings. It checks existing coverage before creating, preserves existing issue content and status, and reports partial success so a retry can reconcile what already exists. Draft requests make no Linear writes; an authorized creation request proceeds without a second approval round. It does not create a local ticket tracker.

Both implement skills first explain the ticket's role in the project's business flow, its direct and indirect ticket relationships, and the implications for this change. They use relevant project requirements and decisions without requiring a specific PRD/design filename. A contradiction between the ticket definition and the discovered business context pauses implementation for user clarification, including contradictions found later during coding or review.

The `worktree` parameter and optional base remain supported. A Linear issue in Backlog can be implemented without first moving it to Todo; Backlog and other non-terminal states are preserved unless a transition is authorized. The existing automatic Todo → In Progress transition applies to an `unstarted` issue only after business context, dependencies, workspace, and executor readiness have been checked. An unresolved blocker is distinct from a Backlog state.

For Codex, the same forms use explicit skill invocation:

```text
$implement-ticket 003 worktree
$implement-ticket 003 worktree dev
$implement-ticket-linear ENG-42 worktree
$implement-ticket-linear ENG-42 worktree dev
```

Both skills default to implementation, verification, review, and a summary. They carry forward existing authorization for commits, PRs, merges, and tracker updates without forcing another landing menu. A missing ticket ID may be resolved from unambiguous conversation or branch context; it never starts the entire backlog. Batches require an explicit scope.

The optional final `via <executor>` clause supports `codex`, `claude`, and `grok`. The selected CLI receives the agreed business context and implements only in the chosen ticket checkout. The invoking host independently verifies and performs ticket-specific review before authorized follow-up. Delegation, workspace, and finishing details live in shared references and are read when needed.

Both update skills reuse the ticket's business context, selected checkout/base, and applicable verification. When the outcome is clear and required acceptance is confirmed, auto mode and an explicit Done request complete without another confirmation. They ask only about a material conflict or missing evidence; a missing formal checklist is fine when the required outcome is otherwise clear and verified. Custom Linear completion states use the same standard, and multiword state names are supported.

```text
$update-ticket
$update-ticket 003 done
$update-ticket-linear ENG-42
$update-ticket-linear ENG-42 In Progress
```

An already-matching status still allows stale dependency/index data and known unfinished operations to be reconciled. The local skill commits only its intended tracker changes via `commit-ticket`, preserving staged code and other edits. The Linear skill keeps Project Context sync and Notion decision logging independent, each honoring its own binding, preference, and prior authorization. Optional document consent or failure does not delay a supported Done transition. Detailed rules are shared references loaded for the relevant operation.

### Git and worktrees

```text
/commit-ticket                        # Stage and commit intended changes; no ticket required
/commit-push-pr                       # Commit if needed, push, and create or reuse a PR
/create-worktree 7                    # Worktree for ticket 007 off origin/main
/create-worktree 7 8 9 dev            # Several tickets at once, based on origin/dev
/merge-worktree 7                     # Merge ticket 007 back, remove worktree, delete branch (same multi-ticket and base args)
/create-worktree-linear ENG-42        # Worktree for Linear issue ENG-42 off origin/main
/create-worktree-linear ENG-42 ENG-43 dev   # Several issues at once, based on origin/dev
/merge-worktree-linear ENG-42         # Merge ENG-42 back, remove worktree, delete branch
/merge-worktree-linear ENG-42 no-cleanup    # Merge and remove the worktree, but keep the branch
```

`commit-ticket` works with or without a ticket. It stages intended unstaged edits, deletions, and new files before committing, alongside any in-scope staged changes. A general request uses the current checkout's pending changes unless the conversation defines a narrower scope or known exclusions. Explicit staged-only or path-limited requests are respected, and unrelated staging and working-tree changes are preserved.

```text
$commit-ticket
$commit-ticket commit the pending typo and layout fixes
$commit-ticket commit only the currently staged changes
```

Messages default to [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/), following repository requirements and explicit user messages. This skill additionally requires an explanatory body for substantive changes: motivation, resulting behavior, important decisions, and relevant verification evidence. Tiny self-explanatory corrections can use a subject alone. Ticket references and scope are optional; no fixed body headings or line count are imposed.

`commit-push-pr` continues from the current state: pending work uses `commit-ticket`, already-committed work proceeds to publishing, and a matching open PR is reused. It preserves the selected worktree and resolves the push destination and PR head/base from the request, implementation context, and repository configuration. The PR description covers the complete branch change and applicable verification, following the repository template and user preferences.

```text
$commit-push-pr
$commit-push-pr push the already-committed work and open a PR into dev
$commit-push-pr use the current worktree and update its existing PR
```

### Agent handoff

```text
/codex-handoff                     # Prepare a local bundle for Codex takeover ($codex-handoff explains this is unnecessary inside Codex)
/grok-handoff                      # Prepare a local bundle for Grok Build takeover (in Codex: $grok-handoff)
/opencode-handoff                  # Prepare a local bundle for OpenCode takeover (in Codex: $opencode-handoff)
/takeover                          # Continue a pending handoff from another agent (in Codex: $takeover)
```

### Agent interaction

```text
/clarify                           # Explain your most recent statement again, with the missing context recovered
/clarify the scoring worker part   # Clarify a named topic from what you just said
/debrief-result                    # Explain what the just-finished result means for the project
/interact-html which caching strategy should we use — 3 options with trade-offs
/interact-html                     # Render the pending questions from the current conversation as a page
```

`clarify` also triggers on its own when the user says they do not understand something you said. It clarifies a *statement*; `clarify-ticket` and `clarify-ticket-linear` clarify a *ticket*. `debrief-result` explains a *result's* meaning for the project and needs no ticket id.

### Docs and maintenance

```text
/feature-catalog                   # Generate a feature catalog for the current project
/readme-builder                    # Generate or refresh README.md from codebase facts + screenshots
/readme-builder no-screenshots     # Same, but skip Playwright screenshot capture
/update-agents                     # Persist what you said you'd remember next time into AGENTS.md and CLAUDE.md
/update-agents use bun, never npm  # Persist this standing instruction into both files
/cktk-upgrade                      # Upgrade cktk and reconcile all supported agent installs
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

- **Codex triggering policy:** `review-ticket`, `feature-catalog`, `design-system-extractor`, `design-system-web-applier`, `design-system-mobile-applier`, `wcag-accessibility-checker`, `interact-html`, `clarify`, `debrief-result`, and `project-advisor` also include descriptions suitable for Codex's implicit skill matching; every other skill (the write-heavy, handoff, and external-service workflows) is explicit-only in its `agents/openai.yaml` policy. `clarify` is read-only and its trigger is a user saying they did not understand, so implicit matching is the point of it. `debrief-result` is the same pattern for a result whose project-level meaning was left unexplained. `project-advisor` matches project direction and prioritization discussions; writes require a save or execution request.
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

Local ticket workflows use:

- `docs/tickets/INDEX.md` — ticket index with status tracking
- `docs/tickets/NNN-<slug>.md` — individual ticket files

Requirements, design decisions, and business context come from the request and relevant project sources; fixed PRD/design filenames are not prerequisites for implementation. Linear workflows use live issues and relations instead of local ticket files.

The UX design skills expect:

- `docs/PRD.md` — product requirements document
- `docs/FEATURES.md` — structured feature catalog (optional for `ux-design`, required for `ux-redesign`)
- `docs/UX_DESIGN.md` — UX design specification (output of `ux-design`, input for `ux-redesign`)

A PRD template is available at `templates/PRD.md`.

## Contributing

See [`AGENTS.md`](AGENTS.md) for the three-tree maintenance rules: every skill in `skills/` must have a matching folder under `.agents/skills/` and a symlink under `.agent/skills/`. After adding or renaming a skill, update all three trees plus `catalog.json` and `README.md`, then run the validation script. Handoff workflow documentation lives in [`docs/agent-handoff.md`](docs/agent-handoff.md) — update it alongside this README when changing the handoff skills, and note that `scripts/test-handoff-tools.sh` asserts specific strings in `README.md`.

## Validation

Run the cross-agent skill validation script after changing skill content or layout. It checks tree parity, portable source identity, resource links, OpenAI metadata, and existing workflow contracts:

```sh
./scripts/check-codex-skills.sh
```

Installer changes use `python3 scripts/test-agent-skills.py` with isolated homes. Run `bash scripts/test-ticket-delegation.sh` when changing the executor adapter, and `bash scripts/test-handoff-tools.sh` for handoff/installation integration. No test calls a live coding model or ticket service.

## License

TODO: no LICENSE file is present in the repository. Add a license file (MIT, Apache-2.0, etc.) and update this section to declare it.
