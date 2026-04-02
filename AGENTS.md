# Repository Guidance

This repository carries three skill trees on purpose:

- `skills/` is the Claude-facing tree (canonical).
- `.agents/skills/` is the Codex-facing tree.
- `.agent/skills/` is the Antigravity-facing tree.

Keep these rules in place when editing the repo:

1. Every skill in `skills/` must have a matching skill folder in `.agents/skills/` and a symlink in `.agent/skills/`.
2. Do not symlink or copy `SKILL.md` between the Claude and Codex trees. The Codex copies are separate documents with Codex-native instructions and metadata. The Antigravity tree uses symlinks directly to `skills/`.
3. Shared support material such as `references/`, `scripts/`, and `assets/` should live under `skills/` and be exposed to Codex through symlinks from `.agents/skills/` when needed.
4. If you add or rename a skill, update all three trees (`skills/`, `.agents/skills/`, `.agent/skills/`), update `README.md`, update `catalog.json`, and rerun `scripts/check-codex-skills.sh`.
5. Prefer explicit `$skill-name` examples in Codex docs for any workflow that changes the repo or calls external services.

