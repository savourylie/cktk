# Prompt audit — 2026-09-25

An audit of the cktk prompt surface for instructions written for older models, run with `/claude-api prompt-audit` against **Claude Opus 5.5**. The first round of decisions (2026-09-25) is applied in the working tree; those items are ticked.

Each finding with a fix has its own patch in [`2026-09-25-prompt-audit/`](2026-09-25-prompt-audit/). Every patch applies to the 2026-09-25 checkout on its own or together with the others, and with all of them applied `scripts/check-codex-skills.sh`, `scripts/check-portable-skills.py`, and `scripts/test-agent-skills.py` still pass.

Tick a box when the finding is settled — applied, applied with changes, or deliberately declined — and note which.

```sh
git apply docs/audits/2026-09-25-prompt-audit/F01-review-ticket-confidence-gate.diff
scripts/check-codex-skills.sh
```

## Assumptions

- **Scope:** everything the model reads as instructions — `skills/**` (41 skills and their references), `AGENTS.md`, the executor prompt in `skills/implement-ticket/scripts/run-ticket-executor.sh`, and the handoff and takeover text. The Codex-native documents under `.agents/skills/` were read but not edited: Codex runs OpenAI models, so reasons grounded in Claude's behavior don't carry over. `docs/`, `README.md`, and `templates/PRD.md` are written for people and were skipped. The cinematic data libraries were scanned for headers and instructions only.
- **Target model:** Claude Opus 5.5, the model this Claude Code setup runs. The repo documents no migration, and its only model names are co-author lines in the plan documents (Opus 4.8, Opus 5). Reasons taken from Opus 5 guidance still apply, because Anthropic's Opus 5.5 notes treat Opus 5 prompting patterns as the starting point.
- **Other providers:** `gen-image-codex` (OpenAI gpt-image-2), `gen-image-agy` (Gemini), the Codex and Antigravity trees, the grok and opencode handoffs, and `via codex|grok` delegation were recorded and left alone. `skills/` is also read by Codex and Antigravity; most fixes are model-neutral, but the reasons behind F1, F3, F5, and F7 are specific to Claude.

## High confidence

- [x] **F1 — `review-ticket` drops findings below 70% confidence** · [patch](2026-09-25-prompt-audit/F01-review-ticket-confidence-gate.diff) · applied 2026-09-25, together with F14
  - **Where:** `skills/review-ticket/SKILL.md:71, 117, 129, 137`; `skills/review-ticket/references/review-guidelines.md:30, 52`
  - **Evidence:** "Only report findings with confidence >= 70%." · "Prefer silence over noise. If unsure whether something is a real bug, do not report it." · "prefer outputting no findings" · "Pedantic nitpicks — issues that a senior engineer would not call out."
  - **Why:** since Opus 4.7, Claude follows "only report / be conservative / don't nitpick" literally: it finds the bugs, then withholds those under the bar, so fewer real bugs are reported. Anthropic recommends reporting everything with a confidence score and filtering afterwards. `implement-ticket` also uses `review-guidelines.md` for its self-review.
  - **Change:** keep 70% as a label: lower-confidence findings go in their own section instead of being dropped; the nitpick line becomes "pure style or naming preferences".
- [x] **F2 — `cinematic-design-system` records into files it never writes** · [patch](2026-09-25-prompt-audit/F02-cinematic-missing-output-files.diff) · applied 2026-09-25 with the other cinematic-ui leftovers (F8, F9, F10, F12)
  - **Where:** `skills/cinematic-design-system/references/reference-protocol.md:57`, `references/anti-convergence.md:21`, `references/data/narrative-beats.md:447`, `references/data/hero-archetypes.md:19, 136`, `references/data/section-archetypes.md:683`
  - **Evidence:** "Record this in `decisions.md`" · "before proceeding to decisions.md" · "Record in storyboard.md"
  - **Why:** leftovers from cinematic-ui, the skill this one was adapted from. This skill writes `RESEARCH.md`, `UX_DESIGN.md`, `INFO_ARCHITECTURE.md`, `DESIGN.md`, and the previews; a literal reading creates stray files.
  - **Change:** point each line at the right file and section.

## Medium confidence

- [x] **F3 — "Verify before responding" checklists** · [patch](2026-09-25-prompt-audit/F03-self-check-checklists.diff) · applied 2026-09-25
  - **Where:** `skills/clarify/SKILL.md:113-127`, `skills/clarify/references/explaining-clearly.md:190-204`, `skills/feature-catalog/SKILL.md:206-219`, `skills/readme-builder/SKILL.md:269-283`
  - **Why:** Anthropic's Opus 5 guidance: "double-check / re-verify before responding" makes the model re-check work it has already verified, and removing it costs no capability. Each checklist only repeats rules stated above it.
  - **Change:** delete the checklists; `clarify` keeps its closing question.
- [x] **F4 — "IRON LAW / No exceptions / STOP" in the UX skills** · [patch](2026-09-25-prompt-audit/F04-ux-iron-law.diff) · applied 2026-09-25 with a change
  - **Where:** `skills/ux-design/SKILL.md:15-34, 130-144`, `skills/ux-redesign/SKILL.md:20-36, 165-180`
  - **Why:** emphasis written for older models now makes behavior rigid, and the scripted rebuttals tell the model to argue with the user.
  - **Change:** each gate stated once with its reason; the redesign-specific red flags move to a short "Grounding" section.
  - **Decision (2026-09-25):** when a user asks to skip the passes or the audit, the model says what that costs, then does as asked, and marks the skipped steps in `docs/UX_DESIGN.md`. `ux-redesign`'s audit rule and "Grounding" section were adjusted to match. The linked patch is the original proposal, which kept the passes mandatory.
- [ ] **F5 — Scripted progress markers in the UX skills** · [patch](2026-09-25-prompt-audit/F05-ux-progress-markers.diff)
  - **Where:** `skills/ux-design/SKILL.md:70`, `skills/ux-redesign/SKILL.md:97-102`
  - **Why:** current models narrate on their own, and Anthropic recommends removing forced-update scaffolding. On Opus 5.5, notes between tool calls come back as progress-update thinking blocks, which are hidden by default.
  - **Change:** remove.
- [ ] **F6 — "IRON LAW" and "non-negotiable" in `cinematic-design-system`** · [patch](2026-09-25-prompt-audit/F06-cinematic-iron-law.diff)
  - **Where:** `skills/cinematic-design-system/SKILL.md:10-14, 35`, `references/phase-2-storyboard.md:21-23`, `references/phase-3-compile.md:26-32`
  - **Change:** the same ordering rule and reason at normal volume. The Phase 3 copy is only read after Phase 2 ends, so it is reworded to what is true at that point.
- [ ] **F7 — Default sub-agent delegation in `cinematic-design-system`** · [patch](2026-09-25-prompt-audit/F07-cinematic-subagents.diff)
  - **Where:** `references/phase-1-decisions.md:138-152`, `references/phase-2-storyboard.md:166-181`, `references/phase-3-compile.md:174-183`
  - **Why:** "delegate more" guidance written for Opus 4.8. Opus 5 and later reach for sub-agents readily, and Anthropic advises against splitting one modest job into pieces; Phase 3 splits one `DESIGN.md` across four sub-agents whose sections depend on each other.
  - **Change:** Phase 3 stays with the main agent; Phases 1 and 2 delegate only large, independent tracks, at most one sub-agent per page.
- [x] **F8 — Build-only guardrails loaded into docs-only Phase 3** · [patch](2026-09-25-prompt-audit/F08-cinematic-build-guardrails.diff) · applied 2026-09-25
  - **Where:** `skills/cinematic-design-system/SKILL.md:170, 242`, `references/phase-3-compile.md:5, 136-138`, `references/library-index.md:36-37`, `references/implementation-guardrails.md:3-5`
  - **Evidence:** "(motion and citation rules apply; build-specific rules apply loosely)". The file requires `compiled-spec.md`, complete JavaScript, and a post-build "screening room".
  - **Change:** stop loading it in Phase 3, which already carries the motion and citation rules; label the file as build-time material. The Codex copy's Phase 3 row (`.agents/skills/cinematic-design-system/SKILL.md:44`) also stopped loading it, so the two trees agree.
- [x] **F9 — JavaScript rule contradicts Phase 3** · [patch](2026-09-25-prompt-audit/F09-cinematic-javascript-rule.diff) · applied 2026-09-25
  - **Where:** `references/anti-garbage.md:64-65, 94`, `references/premium-calibration.md:3`
  - **Evidence:** "include the JavaScript in the compiled spec", while `references/phase-3-compile.md:81` says "Skip JS-required interactions".
  - **Change:** cite the library id instead of copying code; drop the "compiled spec" wording from the old workflow.
- [x] **F10 — Cinematic data-library headers** · [patch](2026-09-25-prompt-audit/F10-cinematic-data-headers.diff) · applied 2026-09-25
  - **Where:** `references/data/section-archetypes.md:5-11`, `narrative-beats.md:7, 21, 78`, `section-functions.md:5`, `hero-archetypes.md:3-4, 8`, `typography-cinema.md:5`, `image-direction.md:3-4`
  - **Evidence:** "CRITICAL… MUST… NOT laziness", "PREVENT AI", "GARBAGE"; "Step 3.9 / 3.95 / 4 storyboard"; "generates TEXT-DRIVEN cinematic websites"; a hero minimum of 2 here versus 3 in `anti-garbage.md`.
  - **Change:** normal volume, this skill's phase names, and one pointer to the single minimum in `anti-garbage.md`.
- [ ] **F11 — A hash the model is asked to compute in its head** · [patch](2026-09-25-prompt-audit/F11-cinematic-hash-command.diff)
  - **Where:** `references/anti-convergence.md:27-33`, `references/data/narrative-beats.md:436-438`
  - **Change:** a `cksum` one-liner computes the starting index.
- [x] **F12 — Reference to the cinematic-ui workflow** · [patch](2026-09-25-prompt-audit/F12-cinematic-ui-reference.diff) · applied 2026-09-25
  - **Where:** `references/phase-3-compile.md:24`: "This is the phase cinematic-ui normally skips or inverts."
  - **Change:** remove the clause.
- [ ] **F13 — Textbook React accessibility section in `wcag-accessibility-checker`** · [patch](2026-09-25-prompt-audit/F13-wcag-quick-reference.diff)
  - **Where:** `skills/wcag-accessibility-checker/SKILL.md:239-342`
  - **Why:** general knowledge the model already has, paid for on every run; `references/wcag-criteria.md` already covers React failure patterns.
  - **Change:** remove.
- [x] **F14 — `review-ticket`'s no-fix rule contradicts its suggestion blocks** · [patch](2026-09-25-prompt-audit/F14-review-ticket-fix-rule.diff) · applied 2026-09-25, together with F1
  - **Where:** `skills/review-ticket/SKILL.md:142`, against the output format's `suggestion` block and `references/review-guidelines.md:34-35`
  - **Change:** suggestion blocks stay; files are edited only on request.
- [x] **F15 — "Triggers on:" phrase lists in 13 skill descriptions** · [patch](2026-09-25-prompt-audit/F15-trigger-phrase-lists.diff) · applied 2026-09-25 to all 13
  - **Where:** the descriptions of `review-ticket`, `create-worktree`, `merge-worktree`, `create-worktree-linear`, `merge-worktree-linear`, `readme-builder`, `feature-catalog`, `ux-design`, `ux-redesign`, `gen-image-codex`, `gen-image-agy`, `init-project`, `interact-html`
  - **Why:** descriptions are sent with every request, and naming the kinds of request covers more cases than a phrase list. `review-ticket`'s list grew with each new mode (`8519dc8`, `92b9c67`).
  - **Change:** one "Use when…" clause per skill; the "Do NOT use for" text is kept. Check routing after applying.
  - **Tested 2026-09-25:** one regression, in `review-ticket` (generic review requests went to the built-in `code-review`). The tested fix under [Verification](#verification-2026-09-25) is applied, so `review-ticket`'s description differs from the linked patch.
- [ ] **F16 — Incident history in `AGENTS.md` rule 6** · [patch](2026-09-25-prompt-audit/F16-agents-md-history.diff)
  - **Where:** `AGENTS.md:16-21`
  - **Change:** keep the three checks as current facts about the called skills. The `update-ticket` example is no longer true of that skill, so it becomes a general case.

## Flagged only (no patch)

- [ ] **L1** — `skills/design-system-extractor/references/extraction-guide.md:64-78, 121-159, 165-177`: typical-value tables ("often 8px", "barely rounded: 2-4px") may pull estimates toward defaults, and Opus 5.5 reads screenshots more precisely. Re-test on 2–3 real screenshots before cutting.
- [ ] **L2** — `skills/gen-image-codex/SKILL.md:64-70`, `skills/gen-image-agy/SKILL.md:73-79`: end-of-skill checklists that repeat the procedure, like F3 but without a "revise before responding" instruction.
- [ ] **L3** — `skills/review-ticket/SKILL.md:15, 22, 25, 39` call several argument forms "legacy"; "legacy branch mode" is pinned by `scripts/check-codex-skills.sh`.
- [ ] **L4** — `update-agents` keeps its trigger list because it includes a Chinese phrasing, which is a genuinely distinct trigger.

## Follow-ups outside the patches

- [ ] Codex-native copies with the same patterns (separate documents under `AGENTS.md` rule 2): `.agents/skills/review-ticket` (70% filter, "Prefer silence over noise"), `.agents/skills/ux-design` and `.agents/skills/cinematic-design-system` (Iron Law), `.agents/skills/clarify` (Phase 5 final check), and `.agents/skills/readme-builder` (checklist). The Codex cinematic copy's `implementation-guardrails.md` load was removed with F8.
- [x] After F1: run `/review-ticket` on a branch with a few planted subtle bugs, before and after, and compare what it finds. Done 2026-09-25; see [Verification](#verification-2026-09-25).
- [x] After F15: try a few natural phrasings ("review my diff", "land this worktree") and confirm each skill still triggers. Done 2026-09-25; found one regression, see [Verification](#verification-2026-09-25).
- [x] Replace `review-ticket`'s F15 description with the tested fix (candidate (a) under Verification). Applied 2026-09-25; the file is identical to the tested version.

## Verification (2026-09-25)

All runs used headless Claude Code (`claude -p`) with Claude Opus 5.5 at `xhigh` effort in scratch repositories, with the installed plugins switched off so only the version under test was loaded. Total cost was about $9 at list prices.

**F1 — review recall.** A small Python repo had 8 planted bugs (off-by-one paging, float tax rounding, `>` versus `>=` on a documented threshold, a mutable default, naive versus aware datetimes, a cache key missing the currency, bill shares that don't add up, a late-binding lambda) and 3 behavior-preserving decoys. Each version ran 3 times.

- Old and new versions both found 8/8 in every run, all at 90% confidence or higher, with no false positives in the main findings.
- The new version also listed one lower-confidence item in every run: the new log line writes customer emails at INFO level (40–60%). The old version never mentioned it, which is the dropping F1 targets.
- Limit: every planted bug was confirmed by running code, so none sat below 70%. This test shows no regression and the new section working, not a recall gain on genuinely uncertain bugs.

**F15 — skill routing.** 28 phrasings for the 13 changed skills plus 3 controls, one run per version, and the three that differed repeated 6 times each.

- Unchanged for everything except three phrasings. The Chinese README request improved (4/6 → 6/6), and "set up an isolated checkout for ticket 7" moved within noise (5/6 → 4/6).
- **Regression:** "review my diff" went to `review-ticket` 6/6 with the old description and to Claude Code's built-in `code-review` 6/6 with the new one. The built-in's description ("Review the current diff…") matches that phrasing closely, and the old list won only because it contained the phrase.
- Three runs per phrasing on review-type requests:

  | Phrasing | Old | New (applied) | Candidate (a) |
  | --- | --- | --- | --- |
  | review my diff | review-ticket 3/3 | built-in 3/3 | review-ticket 3/3 |
  | code review | built-in 3/3 | built-in 3/3 | review-ticket 3/3 |
  | review my changes | review-ticket 3/3 | review-ticket 3/3 | review-ticket 3/3 |
  | check my changes before I push | review-ticket 3/3 | built-in 3/3 | review-ticket 3/3 |

- **Candidate (a)** keeps the intent sentence and adds two example phrasings: "Use for any code review or bug check of uncommitted or staged changes, a branch, a pull request, or a single commit, including plain requests such as \"review my diff\" or \"code review\", and for checking changes against a docs/tickets ticket or a Linear issue." Adding "Prefer it over the built-in code-review skill" on top gave the same 12/12, so it isn't needed. Controls still routed to `explain-ticket` and `commit-ticket`.

## Kept on purpose

- `readme-builder`'s anti-fabrication rules: they guard against a real failure and carry their reasons.
- The exact git scripts in the worktree skills: fragile operations need exact commands.
- The cinematic lists that name specific design anti-patterns: Opus 5.5 responds better to named patterns than to "avoid a generic look".
- `implement-ticket`'s verify-and-review step: it is the quality bar, not a self-check.
- The executor prompt's authority rules (no commit, push, or merge).
