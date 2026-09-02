---
name: "update-agents"
description: "Use when the user explicitly asks to persist durable agent instructions into the repo's AGENTS.md and CLAUDE.md, or invokes $update-agents. Optional argument is the instruction; with no argument, write what you said you would remember next time. Prefer explicit invocation with $update-agents. Do not use to update tickets or README.md."
---

# Update AGENTS.md and CLAUDE.md

Write durable agent instructions into this repo's root `AGENTS.md` and `CLAUDE.md` so later sessions follow them. Invoking this skill is consent to edit those two files. Never commit.

Example: `$update-agents` with no arguments persists what you said you would remember next time; `$update-agents use bun, never npm` persists that standing instruction.

## Arguments

Resolve the instruction from explicit skill arguments when the host provides them; otherwise use the surrounding request. Empty input means persist the durable memory from this conversation.

- Populated argument → distill that text into durable agent-facing prose.
- Empty input → persist what you said you would remember next time, keep in mind, or always do, plus any user correction meant as a standing rule.

## Portable interaction

When it is unclear whether the user meant a subset of several durable items, show every candidate with a stable label and a distinguishing short quote. Use the host's structured choice mechanism only when available and suitable; otherwise ask a concise numbered prose question. Never assume an option limit or an implicit "Other" choice. Ask at most one question at a time.

Refer to other skills by name; use host-native invocation syntax when known.

## Phase 1: Locate the files

1. Repo root via `git rev-parse --show-toplevel`; otherwise the current directory.
2. Read root `AGENTS.md` and `CLAUDE.md` when they exist. On a case-insensitive filesystem, `Agents.md` is the same file as `AGENTS.md` — edit the existing path.
3. If one file only `@`-imports or says to see the other, write into the source file and leave the pointer file unchanged.

## Phase 2: Decide what to persist

A durable instruction is a standing convention, preference, workflow, or refusal that should apply in future sessions.

Skip one-off task state, ticket-specific work, secrets, API keys, conversation recaps, and anything already covered by an equivalent rule in the target file.

Empty input and nothing durable in this conversation → say so and stop. Several durable items → persist all of them; ask only when the user may have meant a subset.

Rewrite each kept item as an imperative rule. Match the language of the target file when it has substantial content; otherwise match the user's language.

## Phase 3: Write both files

For each file that should receive the instruction:

1. Prefer an existing section that already holds this kind of rule (conventions, workflow, notes, or — in `CLAUDE.md` only — Learned User Preferences).
2. Otherwise append a `## Agent notes` section.
3. Match the file's list style.
4. If an equivalent rule is already present, skip that item in that file.
5. If the file is missing, create it with a `# Agent instructions` title plus the new instruction. Do not clone the sibling file.

Keep the new content semantically aligned across the two files. Do not rewrite unrelated sections. Do not touch `GEMINI.md`, `.cursorrules`, nested `AGENTS.md` files, or any other path.

## Phase 4: Report

For each of `AGENTS.md` and `CLAUDE.md`, say whether it was created, patched, left as a pointer, or unchanged. Quote the added or edited rules. Never commit. If the user wants a commit, they can invoke `$commit-ticket`.

## Safety

- Edit only root `AGENTS.md` and `CLAUDE.md` (create them if missing).
- Never commit, push, amend, or call commit / PR / worktree skills.
- Never write secrets or dump the transcript into the files.
