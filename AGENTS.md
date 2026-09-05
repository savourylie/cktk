# Repository Guidance

This repository carries three skill trees on purpose:

- `skills/` is the canonical tree. Skills marked `portable: true` in `catalog.json` have one agent-neutral workflow here.
- `.agents/skills/` is the Codex-facing tree: portable skill folders link to the canonical folders; other skills retain their native documents.
- `.agent/skills/` is the Antigravity-facing tree.

Keep these rules in place when editing the repo:

1. Every skill in `skills/` must have a matching skill folder in `.agents/skills/` and a symlink in `.agent/skills/`.
2. For a portable skill, edit only `skills/<name>/`: link the entire `.agents/skills/<name>` folder to `../../skills/<name>`, keep standard Agent Skills frontmatter, and store Codex UI/policy in `agents/openai.yaml`. Do not maintain a second workflow or generated copy. Unmigrated skills still require distinct Codex documents; do not collapse them without reviewing their behavior. The Antigravity tree links directly to `skills/`.
3. Shared support material such as `references/`, `scripts/`, and `assets/` lives under `skills/`. Portable folder links include it automatically; unmigrated Codex folders expose it through resource symlinks. Install from a full checkout so sibling contracts and called skills remain available.
4. If you add or rename a skill, update all three trees (`skills/`, `.agents/skills/`, `.agent/skills/`), update `README.md`, update `catalog.json`, and rerun `scripts/check-codex-skills.sh`.
5. Prefer explicit `$skill-name` examples in Codex docs for any workflow that changes the repo or calls external services.
6. **When a skill invokes another skill, read the callee's preconditions before writing the call.** Check three things: its hard refusals (`create-worktree`, `merge-worktree`, and both implement twins have them), its uncommitted side effects, and which argument selects the mode you actually want. Every defect found in the 2026-07-25 delegation audit was a caller that had not:
   - `implement-ticket` delegated to `merge-worktree` from inside the worktree that skill explicitly refuses to run in;
   - `create-worktree` edits `$MAIN_ROOT/.gitignore` and deliberately does not commit, which then trips `merge-worktree`'s clean-checkout refusal;
   - `implement-ticket` invoked `review-ticket` with no argument, silently getting generic review instead of ticket mode.

   The same applies in reverse: when you change a skill, grep for callers and for conditions keyed on state you are making more common. `implement-ticket` beginning to create `ticket-NNN-<slug>` on every run made a dormant branch-name test in `update-ticket` start firing in a case it was never written for.
