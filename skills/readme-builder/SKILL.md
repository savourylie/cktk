---
name: readme-builder
user-invocable: true
description: "Create or refresh README.md for a software project. Auto-detects framework, package manager, scripts, env vars; reads existing docs (AGENTS.md, CONTRIBUTING.md, docs/, package.json, pyproject.toml, docker-compose.yml); writes a sectioned README with tagline, quick start, development commands, environment variables, architecture overview, usage, testing, deployment, troubleshooting, and contributing. For browser-renderable apps it captures screenshots of major UI flows via agent-browser and embeds them; pass `no-screenshots` for a pure-text README. When README.md already exists, refreshes recognizable sections from current code while preserving custom user-authored content verbatim. Triggers on: /readme-builder, create README, write README, generate README, update README, refresh README, build documentation for this repo, add a quick-start, document this project, README from code. Do NOT use for: feature catalogs, PRDs, tickets, code review, or API reference docs."
---

**Argument:** `$ARGUMENTS`

# README Builder

Generate or refresh a project's `README.md` from observed facts in the codebase — framework, scripts, env vars, existing docs — plus, for browser-renderable apps, screenshots of major UI flows captured via agent-browser.

The output is a README sized for the project's actual readers: contributors who need to clone and run it, users who want to install and use it, and outside visitors who want to know what it is in the first thirty seconds. Sections that don't apply for the project type are omitted rather than padded with "N/A".

**Anti-fabrication is the single most important rule.** README content shapes how strangers form their first impression of a project — a fabricated command or env var makes that impression a lie. When in doubt, write a `TODO:` placeholder explaining what's missing, and let the user fill it in. See the *Anti-fabrication discipline* section below.

## Inputs

| Argument | Required | Description |
| --- | --- | --- |
| `no-screenshots` | No | Skip screenshot capture entirely. Produces a pure-text README. Without this flag, screenshots are attempted on browser-renderable projects only. |

The argument list is a single optional flag — nothing else is accepted. If `$ARGUMENTS` contains any token that isn't `no-screenshots` (case-insensitive), report `Unknown argument: <token>. Usage: /readme-builder [no-screenshots]` and stop.

**Examples:**
```
/readme-builder
/readme-builder no-screenshots
```

---

## Phase 1: Parse arguments and detect project type

1. **Parse `$ARGUMENTS`:**
   - Tokenize on whitespace.
   - If empty, set `screenshots_enabled = true` (subject to project-type gating in Phase 4).
   - If the single token is `no-screenshots` (case-insensitive), set `screenshots_enabled = false`.
   - Any other token → error + stop with the usage hint above.

2. **Detect project type** using the signals in [`references/project-types.md`](./references/project-types.md). The detection resolves into one of:

   | Type | Examples |
   | --- | --- |
   | `web-app-browser` | Next.js, Vite (React/Vue/Svelte), Nuxt, Astro, SvelteKit, CRA, Remix, Django + templates, Rails + ERB, plain static site |
   | `library` | npm package with no app entry, PyPI package, Go module, Rust crate, Ruby gem |
   | `cli` | Node CLI (`bin` field), Python `[project.scripts]`, Go `main.go` for a binary, Rust binary crate, shell script collection |
   | `api-service` | Express / Fastify / Hono / Koa with no UI, FastAPI / Flask, Go HTTP server, Rails API mode |
   | `native-mobile` | iOS (`*.xcodeproj`), Android (`build.gradle`), React Native, Flutter |
   | `native-desktop` | Electron, Tauri |
   | `monorepo` | `pnpm-workspace.yaml`, `turbo.json`, `nx.json`, `lerna.json`, or workspaces in `package.json` |
   | `unknown` | none of the above signals match cleanly |

   For `monorepo`, ask the user whether they want a top-level README (overview + per-package pointers) or a README for a specific package. Then re-detect the type for that scope.

   For `unknown`, ask the user to describe the project briefly before continuing. Do not guess.

---

## Phase 2: Read existing context

Read the following in order, **skipping any that don't exist** (don't error — just continue). Record what you found and what was absent.

1. **The current README** (`README.md`, `README.rst`, `Readme.md`, etc. — case-insensitive):
   - Read the full file. Parse it into sections by top-level (`##`) headings.
   - For each section, record:
     - The heading text.
     - Whether it maps to a canonical section in [`references/readme-template.md`](./references/readme-template.md) (canonical headings are: *What it does*, *Screenshots*, *Quick start*, *Development*, *Environment variables*, *Architecture*, *Usage*, *API reference*, *Testing*, *Deployment*, *Troubleshooting*, *Contributing*, *License*, and common synonyms — see the template).
     - The original body text (verbatim, for the preserve-custom case in Phase 5).
   - Also capture: the very-top content above the first `##` heading (title, badges, tagline) — preserve it if it looks intentional (badges, HTML, or hand-crafted prose), replace if it looks auto-generated or boilerplate.

2. **Project manifests** — read whichever exist:
   - JS/TS: `package.json` (plus `pnpm-lock.yaml` / `yarn.lock` / `bun.lockb` / `package-lock.json` for the package manager).
   - Python: `pyproject.toml` (plus `uv.lock` / `poetry.lock` / `Pipfile.lock`), `setup.py`, `setup.cfg`, `requirements.txt`.
   - Rust: `Cargo.toml`.
   - Go: `go.mod`.
   - Ruby: `Gemfile`, `*.gemspec`.
   - PHP: `composer.json`.
   - Dart/Flutter: `pubspec.yaml`.
   - Java/Kotlin: `pom.xml`, `build.gradle`, `build.gradle.kts`.

3. **Project docs** — read whichever exist:
   - `AGENTS.md`, `CLAUDE.md` — useful for project conventions and stack descriptions, even though they target agents rather than humans.
   - `CONTRIBUTING.md` — quote relevant snippets in the Contributing section.
   - `LICENSE`, `LICENSE.md`, `LICENSE.txt` — read the first 20 lines to identify the license type (MIT, Apache-2.0, etc.).
   - `CHANGELOG.md` — read the top entry to surface recent direction; do not embed.
   - `CODE_OF_CONDUCT.md`, `SECURITY.md` — note existence; reference from Contributing.

4. **Infra & deployment config** — note presence (don't deep-read unless needed):
   - `Dockerfile`, `docker-compose.yml` / `compose.yml` / `compose.yaml`.
   - `.env`, `.env.example`, `.env.sample`, `.env.template` (read the example/sample/template variants; never read `.env` itself).
   - Hosting platform configs: `vercel.json`, `netlify.toml`, `fly.toml`, `render.yaml`, `app.yaml` (GAE), `wrangler.toml` (CF Workers), `serverless.yml`, `amplify.yml`, `Procfile`, `railway.json`.
   - CI: `.github/workflows/*.yml`, `.gitlab-ci.yml`, `.circleci/config.yml` — note existence only; CI internals don't belong in the README.

5. **`docs/` directory** (if it exists):
   - List top-level filenames.
   - Read `docs/ARCHITECTURE.md`, `docs/SETUP.md`, `docs/DEPLOYMENT.md` if present.
   - Do NOT read every file recursively — that's the user's source of truth, not yours to summarize.

After this phase, you should be able to state with confidence:
- Project name (from manifest `name` field, or repo directory name as fallback).
- Package manager (from lockfile).
- Whether a CONTRIBUTING.md / LICENSE / CHANGELOG / Dockerfile / hosting config exists.
- What the previous README covered, section by section.

---

## Phase 3: Introspect the codebase

This is where you discover the runnable, real facts about the project. Apply the patterns relevant to the detected project type from [`references/project-types.md`](./references/project-types.md). Specifically extract:

### Scripts and commands

- **JS/TS**: `package.json#scripts` — record every script and try to infer purpose from the command body (e.g., `"dev": "next dev"` → dev server; `"build": "tsc && vite build"` → production build; `"test": "vitest"` → test runner).
- **Python**: `pyproject.toml#[tool.poetry.scripts]` or `[project.scripts]`; presence of `Makefile`, `justfile`, `tox.ini`, `noxfile.py`.
- **Go**: `Makefile` targets; standard `go run ./...`, `go build`, `go test ./...`.
- **Rust**: standard `cargo build`, `cargo run`, `cargo test`; plus `[bin]` and `[[bin]]` in `Cargo.toml`.
- **Cross-cutting**: top-level `scripts/` directory — list the executable scripts and a one-line purpose if obvious from a shebang or first comment.

### Environment variables

- Grep the source for: `process.env.<NAME>`, `import.meta.env.<NAME>` (Vite), `os.environ["<NAME>"]`, `os.environ.get("<NAME>")`, `os.getenv("<NAME>")`, `std::env::var("<NAME>")` (Rust), `os.Getenv("<NAME>")` (Go), `ENV["<NAME>"]` (Ruby), `getenv("<NAME>")` (PHP).
- Read `.env.example` / `.env.sample` / `.env.template` if present — these are the authoritative list of expected variables.
- Cross-reference: variables defined in `.env.example` but unused in source → still include (the example is the contract); variables used in source but absent from `.env.example` → include with a TODO note.
- For each variable, record: name, whether it's referenced in code, whether it appears in the example file, and a best-guess description (from a comment near the reference, or the example file).

### Test setup

Check for the existence of any of these and record the test command:

| Signal | Test command |
| --- | --- |
| `vitest.config.*` or `vitest` in scripts | `<pkg-manager> run test` (or `npx vitest`) |
| `jest.config.*` or `jest` in scripts | `<pkg-manager> run test` (or `npx jest`) |
| `playwright.config.*` | `<pkg-manager> exec playwright test` |
| `pytest.ini`, `pyproject.toml#[tool.pytest]`, `tests/` with `test_*.py` files | `pytest` (or `uv run pytest`, `poetry run pytest`) |
| `cargo` project with `tests/` or `#[test]` annotations | `cargo test` |
| Go project with `*_test.go` files | `go test ./...` |
| `spec/` directory + `Gemfile` with `rspec` | `bundle exec rspec` |

If nothing matches → omit the Testing section.

### Architecture cues

Read the top-level directory layout. Look for signals:

- `app/` + `pages/` in a Next.js project → App Router; mention if relevant.
- `src/` vs flat layout — note the convention but don't dwell.
- `apps/` + `packages/` (or `libs/`) → monorepo; describe the workspace layout.
- `components/`, `lib/`, `hooks/`, `utils/`, `services/` — note grouping conventions.
- `migrations/`, `prisma/`, `drizzle/`, `alembic/` → database setup; note in Architecture.
- `public/`, `static/` → static asset directory.

The Architecture section should describe the layout that an outside contributor would need to navigate the repo. It is NOT a feature list (that's `feature-catalog`'s job) and NOT an exhaustive directory tree. Aim for 4–8 bullet points naming the directories that matter.

### Entry points

- Node CLI: `bin` field in `package.json`, or top-level script in `scripts/`.
- Python CLI: `[project.scripts]` entries; files with `if __name__ == "__main__":` blocks.
- Go binary: `main.go` files; `cmd/` directory.
- Rust binary: `[[bin]]` entries; `src/main.rs`.
- Library exports: `main` / `module` / `exports` fields in `package.json`; `__init__.py` in Python packages.

Record each entry point and its purpose. Web apps don't have a single entry point in this sense — skip.

---

## Phase 4: Capture screenshots

Skipped if any of the following are true:
- `screenshots_enabled` is `false` (the user passed `no-screenshots`).
- Project type is `library`, `cli`, or `api-service` — these don't have UIs.
- Project type is `native-mobile` — no auto-capture in v1; leave a TODO placeholder in the Screenshots section explaining the user should add screenshots manually.

For all other types, follow the protocol in [`references/screenshot-strategy.md`](./references/screenshot-strategy.md). Summary:

1. **Discover the dev-server command** from `package.json#scripts` (`dev`, `start`, `serve`) or framework defaults.
2. **Discover the port** the dev server will listen on — check config files (`vite.config.*`, `next.config.*`), environment variables, or fall back to the framework default (Next.js 3000, Vite 5173, Astro 4321, etc.).
3. **Start the dev server with `run_in_background: true`** in the Bash tool. Save the background task ID.
4. **Wait for the port to respond** by polling `curl -s http://localhost:<port>/` (or using `Monitor` with an until-loop) until you get a non-error response or a 30-second timeout elapses.
5. **Discover routes to capture.** Default to 3–5 routes:
   - The root path (`/`).
   - Up to 4 additional routes inferred from navigation components (read the navbar / sidebar / route definitions to find the most user-visible routes).
   - Prefer public / unauthenticated routes — skip anything that obviously requires login unless the user has provided auth.
6. **Capture each route with `agent-browser`**, following [`references/screenshot-strategy.md`](./references/screenshot-strategy.md): a named session, viewport `1280×800`, `open` the local URL, `screenshot` to the save path. Load `agent-browser skills get core` before the first command.
7. **Save screenshots** to `docs/images/` (create if missing) — unless the project already has a `public/` directory with a `readme/` or `images/` sub-folder convention, in which case use that. Filenames: `<route-slug>.png` (e.g., `home.png`, `dashboard.png`, `settings.png`).
8. **Stop the dev server** by killing the background task, and close the named session with `agent-browser --session "$SESSION" close`.
9. **On any failure** (port collision, dev server hangs past the timeout, auth wall, `agent-browser` missing or unable to connect):
   - Stop / kill the dev server cleanly and close the named browser session.
   - Record the failure reason (one line).
   - Continue to Phase 5 — the README will be written without screenshots, with a `TODO: screenshots failed — <reason>. Re-run /readme-builder after fixing, or add screenshots manually.` note in place of the gallery.

For `native-desktop`, follow the Electron and Tauri rules in [`references/screenshot-strategy.md`](./references/screenshot-strategy.md). Electron is captured by connecting `agent-browser` over CDP. Tauri is captured only when its frontend already serves a localhost URL.

---

## Phase 5: Compose the README

1. **Load the canonical template** from [`references/readme-template.md`](./references/readme-template.md).

2. **Determine the section list** for the detected project type. The template includes a type→sections matrix.

3. **Draft each applicable section** from observed facts:
   - Use the per-section drafting rules in the template.
   - Reference only what you found in Phases 2 and 3.
   - Where you don't have a confident answer, write `TODO:` followed by a one-line note about what's missing (e.g., `TODO: deployment process not yet documented in the repo`).
   - Keep prose short. README readers skim. One- to three-sentence section openers, then code blocks or bullets.

4. **Merge with the existing README** (if Phase 2 found one):
   - **Canonical sections** that exist in both: replace the body with the freshly-drafted content.
   - **Custom sections** in the existing README (e.g., *Sponsors*, *Acknowledgements*, *Roadmap*, *FAQ*, *Compatibility*, *Philosophy*) that don't match any canonical heading: preserve verbatim. Insert at the same relative position they had in the original (e.g., if *Sponsors* was between *Contributing* and *License*, keep it there).
   - **Top-of-file pre-heading content** (title + tagline + badges): preserve verbatim if it contains badges, HTML, or what looks like hand-crafted prose. Otherwise replace with the freshly-drafted title + tagline.
   - **Reordering**: do not reorder custom sections relative to each other. Canonical sections follow the template order; custom sections slot in at the position closest to their original location.

5. **Write the result to `README.md`** at the project root. Do not commit — leave it in the working tree for the user to review and commit themselves.

---

## Phase 6: Report

Print a short summary to the conversation:

```
README written: ./README.md
Project type: <type>
Sections written: <count> (<list>)
Sections preserved verbatim: <count> (<list>) [or "none"]
Screenshots: <captured count> saved to <path> [or "skipped: <reason>"]
TODOs in document: <count>
```

Then, if any TODOs were left, list them inline so the user can spot them without re-opening the file:

```
TODOs to address:
- <line context>: <todo text>
- ...
```

End the response with: "Review the README before committing — particularly any TODO markers."

---

## Anti-fabrication discipline

This is the single most important rule. README content shapes how strangers form their first impression of the project — a fabricated command is a lie that costs the project's credibility.

**Do NOT:**
- Invent install / dev / build / test commands that aren't in `package.json#scripts`, the `Makefile`, `pyproject.toml`, `Cargo.toml`, or another manifest you actually read.
- Invent environment variables that aren't referenced in source or declared in `.env.example`.
- Invent deployment targets that aren't configured in the repo (no Vercel section unless `vercel.json` / `.vercel/` exists; no Docker section unless a `Dockerfile` exists; no Fly section unless `fly.toml` exists; etc.).
- Invent prerequisites — Node version, Python version, system dependencies — beyond what manifests declare (`engines` field, `python_requires`, etc.).
- Invent test commands beyond what test-runner configs and scripts actually support.
- Invent features in the *What it does* paragraph. Describe what the codebase clearly does; do not extrapolate into a roadmap.

**When in doubt, TODO it.** A README with three TODOs the user fills in is honest. A README with three confidently-stated falsehoods damages the project. Always favour the TODO.

**TODO marker format:**
```
TODO: <what's missing and how to resolve it>
```
Examples:
- `TODO: deployment process not documented in repo — add details if this project ships to a hosting platform.`
- `TODO: confirm Node version requirement — no engines field in package.json.`
- `TODO: add screenshots manually — auto-capture failed (port 3000 already in use).`

---

## Checklist

Before reporting completion, confirm:

- [ ] `$ARGUMENTS` parsed; unknown tokens rejected.
- [ ] Project type detected (or user disambiguated `unknown` / `monorepo`).
- [ ] All applicable manifest / doc / config files inspected.
- [ ] Scripts, env vars, test setup, architecture cues, and entry points captured.
- [ ] Screenshots phase ran (captured, skipped by flag, skipped by type, or failed cleanly).
- [ ] Existing README's custom sections preserved verbatim.
- [ ] Existing README's intentional top-of-file content (badges, HTML) preserved.
- [ ] No fabricated commands, env vars, or deployment targets.
- [ ] TODOs used wherever a confident statement couldn't be made.
- [ ] `README.md` written; no commit made.
- [ ] Summary printed with TODO list.

---

## References

- [`references/project-types.md`](./references/project-types.md) — Detection signals + per-type guidance for which sections apply.
- [`references/screenshot-strategy.md`](./references/screenshot-strategy.md) — agent-browser capture, dev-server discovery, port handling, failure modes.
- [`references/readme-template.md`](./references/readme-template.md) — Canonical section order, per-section drafting rules, example output blocks.
