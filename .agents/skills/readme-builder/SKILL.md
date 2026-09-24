---
name: "readme-builder"
description: "Create or refresh README.md for a software project from observed facts (framework, scripts, env vars, existing docs) plus optional UI screenshots via agent-browser. Use when the user asks to generate, refresh, or build a README for a repo, document a project, or add a quick-start. Prefer explicit invocation with $readme-builder."
---

**Argument:** `$ARGUMENTS`

# README Builder

Generate or refresh a project's `README.md` from observed facts — framework, scripts, env vars, existing docs — plus, for browser-renderable apps, screenshots of major UI flows captured via agent-browser.

Anti-fabrication is the single most important rule. README content shapes how strangers form their first impression of a project — a fabricated command or env var makes that impression a lie. When in doubt, write a `TODO:` placeholder and let the user fill it in. See **Anti-fabrication discipline** below.

## Arguments

| Argument | Required | Description |
| --- | --- | --- |
| `no-screenshots` | No | Skip screenshot capture entirely. Produces a pure-text README. |

Argument grammar: tokenize `$ARGUMENTS` on whitespace. The only accepted token is `no-screenshots` (case-insensitive). Any other token → error and stop with `Unknown argument: <token>. Usage: $readme-builder [no-screenshots]`.

**Examples:**

```
$readme-builder
$readme-builder no-screenshots
```

## Phase 1: Parse arguments and detect project type

1. Parse `$ARGUMENTS`. Empty → `screenshots_enabled = true`. `no-screenshots` → `screenshots_enabled = false`. Any other token → error and stop.

2. Detect project type using the signals in [project-types.md](./references/project-types.md). The detection resolves into one of:

   | Type | Examples |
   | --- | --- |
   | `web-app-browser` | Next.js, Vite, Nuxt, Astro, SvelteKit, CRA, Remix, Django + templates, Rails + ERB, static site |
   | `library` | npm package with no app entry, PyPI package, Go module, Rust crate, Ruby gem |
   | `cli` | Node CLI (`bin` field), Python `[project.scripts]`, Go `main.go` binary, Rust binary crate |
   | `api-service` | Express / Fastify / Hono with no UI, FastAPI / Flask, Go HTTP server, Rails API mode |
   | `native-mobile` | iOS (`*.xcodeproj`), Android (`build.gradle`), React Native, Flutter |
   | `native-desktop` | Electron, Tauri |
   | `monorepo` | `pnpm-workspace.yaml`, `turbo.json`, `nx.json`, `lerna.json`, package.json workspaces |
   | `unknown` | none of the above match cleanly |

   For `monorepo`, ask the user whether they want a top-level README or a README for a specific package, then re-detect the type for that scope. For `unknown`, ask the user to describe the project briefly before continuing. Do not guess.

## Phase 2: Read existing context

Read the following in order, skipping any that don't exist:

1. **Current README** (`README.md`, `README.rst`, case-insensitive). Parse into sections by `##` headings. For each section, record the heading text, whether it maps to a canonical section in [readme-template.md](./references/readme-template.md), and the original body verbatim. Also capture the pre-heading content (title, badges, tagline).

2. **Project manifests** — whichever exist:
   - JS/TS: `package.json` plus lockfile (`pnpm-lock.yaml` / `yarn.lock` / `bun.lockb` / `package-lock.json`).
   - Python: `pyproject.toml` plus lockfile, `setup.py`, `setup.cfg`, `requirements.txt`.
   - Rust: `Cargo.toml`. Go: `go.mod`. Ruby: `Gemfile`, `*.gemspec`. PHP: `composer.json`.
   - Dart/Flutter: `pubspec.yaml`. Java/Kotlin: `pom.xml`, `build.gradle(.kts)`.

3. **Project docs** — whichever exist: `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `LICENSE*` (first 20 lines), `CHANGELOG.md` (top entry), `CODE_OF_CONDUCT.md`, `SECURITY.md`.

4. **Infra & deployment config** — note presence (do not deep-read unless needed): `Dockerfile`, `docker-compose.yml`, `.env.example` / `.env.sample` / `.env.template` (never read `.env` itself), hosting configs (`vercel.json`, `netlify.toml`, `fly.toml`, `render.yaml`, `app.yaml`, `wrangler.toml`, `serverless.yml`, `amplify.yml`, `Procfile`, `railway.json`), CI files under `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/config.yml`.

5. **`docs/` directory** if present: list top-level filenames; read `docs/ARCHITECTURE.md`, `docs/SETUP.md`, `docs/DEPLOYMENT.md` if they exist. Do not read every file recursively.

After this phase, you should be able to state: project name (manifest `name` field or repo directory name), package manager, what extra docs and configs exist, and what the previous README covered section by section.

## Phase 3: Introspect the codebase

Apply the patterns relevant to the detected project type from [project-types.md](./references/project-types.md). Extract:

### Scripts and commands

- **JS/TS**: every `package.json#scripts` entry; infer purpose from the command body.
- **Python**: `pyproject.toml#[tool.poetry.scripts]` or `[project.scripts]`; `Makefile`, `justfile`, `tox.ini`, `noxfile.py` targets.
- **Go**: `Makefile` targets; standard `go run ./...`, `go build`, `go test ./...`.
- **Rust**: standard cargo commands plus `[bin]` / `[[bin]]` entries.
- Top-level `scripts/` directory: list executable scripts with a one-line purpose if obvious from shebang or first comment.

### Environment variables

- Grep source for `process.env.<NAME>`, `import.meta.env.<NAME>`, `os.environ["<NAME>"]`, `os.environ.get(...)`, `os.getenv(...)`, `std::env::var(...)`, `os.Getenv(...)`, `ENV["<NAME>"]`, `getenv(...)`.
- Read `.env.example` / `.env.sample` / `.env.template` — the authoritative list.
- Cross-reference: variables defined in example but unused in source still get included (example is the contract). Variables used in source but missing from the example get a TODO note.

### Test setup

| Signal | Test command |
| --- | --- |
| `vitest.config.*` / `vitest` in scripts | `<pkg-manager> run test` |
| `jest.config.*` / `jest` in scripts | `<pkg-manager> run test` |
| `playwright.config.*` | `<pkg-manager> exec playwright test` |
| `pytest.ini`, `[tool.pytest]`, `tests/test_*.py` | `pytest` (or `uv run pytest`, `poetry run pytest`) |
| `cargo` project with `tests/` or `#[test]` | `cargo test` |
| Go project with `*_test.go` files | `go test ./...` |
| `spec/` + `rspec` in Gemfile | `bundle exec rspec` |

If nothing matches → omit the Testing section.

### Architecture cues

Read top-level directory layout. Note: `app/` + `pages/` (Next.js App Router), `src/` vs flat, `apps/` + `packages/` (monorepo), `components/`, `lib/`, `hooks/`, `utils/`, `services/`, `migrations/` / `prisma/` / `drizzle/` / `alembic/` (DB setup), `public/` / `static/`. The Architecture section should help an outside contributor navigate the repo. Aim for 4–8 bullets. It is NOT a feature list (that's `$feature-catalog`'s job) and NOT an exhaustive directory tree.

### Entry points

- Node CLI: `bin` field, top-level scripts. Python CLI: `[project.scripts]`, `if __name__ == "__main__":` blocks. Go binary: `main.go`, `cmd/`. Rust binary: `[[bin]]`, `src/main.rs`. Library exports: `main` / `module` / `exports` in `package.json`, `__init__.py` for Python.

Web apps don't have a single entry point in this sense — skip.

## Phase 4: Capture screenshots

Skip if any of the following is true:

- `screenshots_enabled` is `false` (user passed `no-screenshots`).
- Project type is `library`, `cli`, or `api-service`.
- Project type is `native-mobile` — write a TODO placeholder in the Screenshots section asking the user to add screenshots manually.

For all other types, follow the protocol in [screenshot-strategy.md](./references/screenshot-strategy.md). Summary:

1. **Discover the dev-server command** from `package.json#scripts` (`dev`, `start`, `serve`) or framework defaults.
2. **Discover the port** from script flags, framework config (`vite.config.*`, `next.config.*`, etc.), env example, or framework default (Next.js 3000, Vite 5173, Astro 4321, Django 8000, Rails 3000, Flask 5000, FastAPI 8000).
3. **Start the dev server in the background** (record the task/PID so you can stop it later).
4. **Wait for the port to respond** by polling `curl -s http://localhost:<port>/` (or equivalent) until a 2xx/3xx/4xx is returned or 30 seconds elapse.
5. **Discover routes** — default to 3–5: the root path plus up to 4 routes inferred from navigation components or route definitions. Prefer public / unauthenticated routes.
6. **Capture each route with `agent-browser`**, following [screenshot-strategy.md](./references/screenshot-strategy.md): a named session, viewport `1280×800`, `open` the local URL, `screenshot` to the save path. Load `agent-browser skills get core` before the first command.
7. **Save screenshots** to `public/readme/` if `public/readme/` already exists, else create and use `public/readme/` for `web-app-browser` projects that ship a `public/` directory (Next.js, Astro, SvelteKit, Vite). Otherwise create and use `docs/images/`. Filenames: slugified route (`home.png`, `dashboard.png`, etc.). Always `.png`.
8. **Stop the dev server** cleanly, and close the named session with `agent-browser --session "$SESSION" close`. Always — even on failure. Leaving a runaway background process is hostile UX.
9. **On any failure** (no dev script, port collision, server never ready, auth wall, `agent-browser` missing or unable to connect, navigation error): stop the server, close the named browser session, record a one-line reason, continue to Phase 5. The README will get a `TODO: screenshots failed — <reason>` note in place of the gallery.

For `native-desktop`, follow the Electron and Tauri rules in [screenshot-strategy.md](./references/screenshot-strategy.md). Electron is captured by connecting `agent-browser` over CDP. Tauri is captured only when its frontend already serves a localhost URL.

## Phase 5: Compose the README

1. **Load the canonical template** from [readme-template.md](./references/readme-template.md).

2. **Determine the section list** for the detected project type (the template includes a type → sections matrix).

3. **Draft each applicable section** from observed facts. Reference only what you found in Phases 2 and 3. Where you don't have a confident answer, write `TODO:` followed by a one-line note. Keep prose short.

4. **Merge with the existing README** if Phase 2 found one:
   - **Canonical sections** that exist in both → replace the body with the freshly-drafted content.
   - **Custom sections** in the existing README (e.g., *Sponsors*, *Acknowledgements*, *Roadmap*, *FAQ*) that don't map to any canonical heading → preserve verbatim at their original relative position.
   - **Top-of-file content** (title, tagline, badges) → preserve verbatim if it contains badges, HTML, or hand-crafted prose; otherwise replace with the freshly-drafted title + tagline.
   - Do not reorder custom sections relative to each other. Canonical sections follow the template order; custom sections slot in at the position closest to their original location.

5. **Write the result to `README.md`** at the project root. Do not commit — leave it in the working tree for the user.

## Phase 6: Report

Print a short summary:

```
README written: ./README.md
Project type: <type>
Sections written: <count> (<list>)
Sections preserved verbatim: <count> (<list>) [or "none"]
Screenshots: <captured count> saved to <path> [or "skipped: <reason>"]
TODOs in document: <count>
```

Then, if any TODOs were left, list them inline so the user can spot them without reopening the file. End with: "Review the README before committing — particularly any TODO markers."

## Anti-fabrication discipline

This is the single most important rule. A fabricated command is a lie that costs the project's credibility.

**Do NOT:**

- Invent install / dev / build / test commands that aren't in `package.json#scripts`, the `Makefile`, `pyproject.toml`, `Cargo.toml`, or another manifest you actually read.
- Invent environment variables that aren't referenced in source or declared in `.env.example`.
- Invent deployment targets that aren't configured in the repo (no Vercel section unless `vercel.json` / `.vercel/` exists; no Docker section unless a `Dockerfile` exists; no Fly section unless `fly.toml` exists; etc.).
- Invent prerequisites — Node version, Python version, system dependencies — beyond what manifests declare.
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

## References

- [project-types.md](./references/project-types.md) — Detection signals and per-type section matrix.
- [screenshot-strategy.md](./references/screenshot-strategy.md) — agent-browser capture, dev-server discovery, port handling, failure modes.
- [readme-template.md](./references/readme-template.md) — Canonical section order, per-section drafting rules, example output blocks.
