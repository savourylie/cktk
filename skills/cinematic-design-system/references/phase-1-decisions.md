# Phase 1 — Decisions

**Output**: `docs/RESEARCH.md` (copy `assets/FILM_TEMPLATE/RESEARCH.md` and fill it in)

**Read at entry**: this file, `demo-uniqueness.md`, `anti-convergence.md`, `reference-protocol.md` (only if user provided references), and `data/directors-200.md`.

**Do not read at entry**: anything else. Phase 2 and Phase 3 data libraries are loaded in their own phases.

## Goal

Turn the user's questionnaire answers into a committed director + film + genre + niche pairing, a full research pass, a demo uniqueness audit, and a primary composition family — all written to `docs/RESEARCH.md`.

Phase 1 is blocked from starting until the Start Questionnaire is complete. See SKILL.md for the questionnaire sequence.

## Entry Specification Derivation

After the questionnaire closes, compute the committed `(director, film, genre)` triple using these rules. Never advance to research until the triple is determined.

| User supplied | Skill does |
|---|---|
| *film only* | **Derive** director and genre from the film. Web research when available; otherwise look up the film in `data/directors-200.md` via grep. |
| *director only* | Pick a film from the director's filmography via web research or `data/directors-200.md`. Record the implicit genre. |
| *genre only* | Pick a director from `data/directors-200.md` appropriate to the genre. Then pick a film from that director's filmography. |
| *director + genre* | Pick a film within that genre, ideally from the director's own filmography. If the director has never worked in that genre, use their lens against a genre-typical film and note the mismatch. |
| *director + film* | Use both as given. Allowed even if the director did not make that film — the director becomes the *lens*, the film becomes the *reference material*. Record the mismatch explicitly. |
| *genre + film* | **Disallowed.** The film already implies a genre. If both somehow arrive, keep the film and discard the genre with a one-line note in RESEARCH.md. The Start Questionnaire should block this combination at selection time. |
| *nothing* (Surprise me) | Pick a genre → director → film (or pick a film and derive director + genre from it). Honor the Demo Uniqueness Protocol shell-ban list when choosing. |

**Note for Screenshot entry mode**: inspect the reference image or URL first and infer a likely `(director, film, genre)` triple. Ask the user to confirm before committing. Once confirmed, the rules above apply.

## Anti-Convergence: Three-Question Film Selection Test

Before committing to the film, answer these three questions from `anti-convergence.md`. If any answer is unsatisfactory, choose a different film before proceeding.

1. **What specific visual problem does this film solve for this niche?** Name a concrete cinematographic quality — not "it feels premium" or "it has a dark aesthetic". Example: *"Tarkovsky's Stalker uses extreme horizontal negative space and slow lateral reveals that match this architecture firm's need for spatial patience."*

2. **Would this same film work equally well for three unrelated niches?** If yes, the selection is too generic. A film that "works for any premium brand" is not a director's choice — it is a mood board.

3. **Are you picking the film or the film's reputation?** If the reasoning relies on reputation ("everyone knows this film is dark and sharp") rather than specific scenes, shots, or director decisions, that's association, not analysis. Rebuild justification from the film itself.

Record the three answers in `RESEARCH.md` under *Film → Why this film for this niche*.

## Web Research (required when web access is available)

When web access is available, research the committed director and film. This is **required, not optional**. Use primary/authoritative sources first, then secondary analysis to deepen interpretation.

Gather these signals:

- Film palette and lighting behavior (dominant hues, accent strategy, contrast logic)
- Cinematography patterns (framing logic, camera behavior, scene rhythm, shot length)
- Production design and material cues (surfaces, textures, atmospheric layers)
- Director signature techniques (3 specific moves, not general reputation)
- 2-3 premium sites in the same niche as the user's project (to inform the shared system)

Record findings in `RESEARCH.md` under *Film Research Notes* and *Niche References*. Keep notes focused on structural signals. **Do not** paste plot summaries or trivia.

**If web access is unavailable**: say so explicitly in `RESEARCH.md`, mark the research pass as weaker, and continue with best-effort inference from `data/directors-200.md` and the skill's other data libraries.

## Reference Decomposition (conditional)

If the user provided visual references (screenshot, URL, mood board), apply the protocol from `reference-protocol.md`:

1. **Classify by risk** — social platforms are high risk; brand/campaign sites are medium; editorial and film institutions are low.
2. **Extract only borrowable dimensions** — rhythm, density, typography attitude, image treatment, materiality, framing, interaction restraint, navigation posture.
3. **Forbid** full section order copying, hero composition recreation, grid skeleton reuse, color combination cloning without film justification.
4. **Rewrite** borrowed dimensions through the committed director and film.

Record the classification, borrowed dimensions, rejected dimensions, and rewriting plan in `RESEARCH.md` under *Reference Decomposition*. If no references were supplied, delete that section entirely.

**Watch for social-platform drift**: if the user's reference is Instagram/Pinterest/Behance/Medium-like, treat it as high risk. Extract only structural dimensions. Reject surface aesthetic entirely. See `anti-garbage.md` → Reference Drift.

## Demo Uniqueness Protocol

Run `demo-uniqueness.md` before closing Phase 1. Three artifacts must land in `RESEARCH.md`:

1. **Previous-work audit** — recurring shell traits from the user's prior outputs
2. **Shell-ban list** — layout traits forbidden for this project
3. **Primary composition family** — the committed structural direction, different from the user's most recent comparable work

If no prior outputs exist, still write a shell-ban list targeting common fallback templates.

## Sub-Agent Delegation

If the environment supports sub-agents, delegate these bounded Phase 1 tasks once the director + film are committed:

- Film research (palette, cinematography, signature techniques)
- Niche research (2-3 premium sites in the same niche)
- Reference decomposition (for each user-supplied reference)

The lead agent retains responsibility for:

- Committing the `(director, film, genre)` triple
- Writing the Demo Uniqueness Audit
- Approving the research pass before Phase 2 begins

Do not let multiple agents independently redefine the director or film.

## Phase 1 Completion Gate

Phase 2 is blocked until `docs/RESEARCH.md` has all of the following:

- [ ] Entry mode recorded
- [ ] Director, film, genre, niche, pages all committed
- [ ] Anti-convergence 3-question test answered
- [ ] Film research notes (or explicit "web access unavailable" marker)
- [ ] 2-3 niche references (when web access available)
- [ ] Reference decomposition (if user supplied references) or section deleted
- [ ] Previous-work audit
- [ ] Shell-ban list
- [ ] Primary composition family
- [ ] Research pass quality marked (strong / adequate / weak)

When all boxes are checked, close Phase 1 and move to `phase-2-storyboard.md`.
