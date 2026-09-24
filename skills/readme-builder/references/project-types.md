# Project Type Detection

This reference is loaded during Phase 1 of the readme-builder workflow. It defines how to classify a project and which README sections apply for each type.

## Table of Contents

1. [Detection signals](#detection-signals)
2. [Type → applicable sections matrix](#type--applicable-sections-matrix)
3. [Per-type exploration hints](#per-type-exploration-hints)
4. [Ambiguity resolution](#ambiguity-resolution)

---

## Detection signals

Walk these in order. The first cluster that matches wins. If two clusters tie (e.g., a Next.js app inside a monorepo), match the more specific one (monorepo wins at the outer level; re-detect inside the chosen package).

### `monorepo`

Any of:
- `pnpm-workspace.yaml`
- `turbo.json`
- `nx.json`
- `lerna.json`
- `package.json` containing a `workspaces` field
- A top-level `apps/` AND `packages/` (or `libs/`) directory pair with their own manifests

When matched, ask the user whether they want:
- A **top-level README** that describes the monorepo as a whole and points to each package, OR
- A README for a specific package (then re-run detection scoped to that package directory).

### `web-app-browser`

Any of:
- `next.config.*` (Next.js)
- `vite.config.*` AND a React/Vue/Svelte/Solid import in any file (Vite SPA)
- `nuxt.config.*` (Nuxt)
- `astro.config.*` (Astro)
- `svelte.config.*` AND `@sveltejs/kit` in `package.json` (SvelteKit)
- `angular.json` (Angular)
- `remix.config.*` OR `@remix-run/*` in deps (Remix)
- `gatsby-config.*` (Gatsby)
- `react-scripts` in `package.json#dependencies` or `devDependencies` (CRA)
- `manage.py` AND a `templates/` directory (Django with server-rendered UI)
- `config/routes.rb` AND `app/views/` (Rails with ERB/HAML)
- `index.html` at root with `<script type="module">` and no other manifest hints (plain static site)

### `api-service`

Any of:
- `package.json` with `express` / `fastify` / `hono` / `koa` / `@hapi/hapi` in dependencies AND no UI framework in the same project
- `requirements.txt` / `pyproject.toml` with `fastapi` / `flask` / `django-rest-framework` / `starlette` AND no template directory
- `cmd/` directory with a `main.go` that imports `net/http` or a router framework (`gin`, `echo`, `chi`, `gorilla/mux`)
- `Cargo.toml` with `axum` / `actix-web` / `rocket` / `warp` in dependencies
- `Gemfile` with `--api` mode or `rails-api` (Rails API mode)

### `cli`

Any of:
- `package.json` with a `bin` field pointing to one or more executables
- `pyproject.toml` with `[project.scripts]` entries
- Top-level `cmd/` directory in a Go project, with one or more `main.go` files producing binaries
- `Cargo.toml` with `[[bin]]` entries
- Files with `#!/usr/bin/env <interpreter>` shebangs at the top of a `bin/` or `scripts/` directory
- The project's only entry point is a CLI binary (no HTTP server, no UI)

### `library`

Any of:
- `package.json` with `main` / `module` / `exports` fields AND no `bin` AND no UI framework AND no HTTP server framework
- `pyproject.toml` with `[project]` metadata AND no `[project.scripts]` AND no FastAPI/Flask/Django
- `Cargo.toml` with `[lib]` AND no `[[bin]]`
- `go.mod` with a package name AND no `main.go` files producing a binary
- `*.gemspec` AND no Rails / Sinatra dependency

### `native-mobile`

Any of:
- `*.xcodeproj` or `*.xcworkspace` (iOS)
- `build.gradle` AND `AndroidManifest.xml` (Android)
- `react-native.config.js` OR `@react-native/*` in deps (React Native)
- `pubspec.yaml` with `flutter` declared (Flutter)
- `Cargo.toml` with `bevy` AND target = mobile (rare; treat as native-mobile)

### `native-desktop`

Any of:
- `electron` / `electron-builder` in `package.json#devDependencies` or `dependencies`
- `tauri.conf.json` OR `@tauri-apps/api` in deps
- `*.csproj` with `OutputType=WinExe` (.NET desktop)
- `setup.py` or `pyproject.toml` with `pyinstaller` / `briefcase` for desktop targets

### `unknown`

None of the above matched, OR multiple matched without a clear winner. Ask the user:

> I couldn't confidently classify this project. Could you describe it in one sentence — e.g., "it's a CLI for X" or "it's a library that wraps Y"? I'll use that to pick the right README sections.

Do not guess.

---

## Type → applicable sections matrix

The matrix below is consumed by Phase 5. A `✓` means write the section; `—` means skip; `if X` means conditional; `TODO` means leave a placeholder.

| Section | web-app-browser | library | cli | api-service | native-mobile | native-desktop |
| --- | :-: | :-: | :-: | :-: | :-: | :-: |
| Title + tagline | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| What it does | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Screenshots | ✓ (unless `no-screenshots`) | — | — | — | TODO | Electron via agent-browser; Tauri only with a frontend URL; else TODO |
| Quick start | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Development | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Environment variables | if any found | — | if any found | if any found | if any found | if any found |
| Architecture | ✓ | — | — | ✓ | ✓ | ✓ |
| Usage | — | ✓ | ✓ | ✓ | — | — |
| API reference | — | if public API exports detected | — | if endpoints detected | — | — |
| Testing | if test setup found | if test setup found | if test setup found | if test setup found | if test setup found | if test setup found |
| Deployment | ✓ | — | if a release/publish flow exists | ✓ | if app-store config exists, else TODO | if installer config exists, else TODO |
| Troubleshooting | TODO placeholder | TODO placeholder | TODO placeholder | TODO placeholder | TODO placeholder | TODO placeholder |
| Contributing | ✓ if CONTRIBUTING.md or open-source license | ✓ | ✓ | ✓ | ✓ | ✓ |
| License | if LICENSE present | if LICENSE present | if LICENSE present | if LICENSE present | if LICENSE present | if LICENSE present |

For `monorepo` at the top level, write a custom outline:
- Title + tagline
- What it does (overview of the workspace)
- Architecture (workspace layout — list each app/package with a one-line purpose)
- Quick start (workspace-level install + the most-common dev command)
- Per-package READMEs (a table linking to each `apps/*/README.md` or `packages/*/README.md`)
- Contributing + License

For `unknown`, skip the matrix entirely and ask the user to describe the project before writing anything.

---

## Per-type exploration hints

These supplement the introspection in Phase 3 of the main skill. Where similar patterns exist in `feature-catalog/references/exploration-strategies.md`, prefer that document as the deeper reference.

### web-app-browser

- **Dev command**: `package.json#scripts.dev`, `.scripts.start`, `.scripts.serve`. Framework defaults if no script: Next.js `next dev`, Vite `vite`, Astro `astro dev`, SvelteKit `vite dev`.
- **Build command**: `scripts.build` (almost always present).
- **Architecture cues**: `app/` vs `pages/` (Next.js routing model); `src/components/`, `src/lib/`, `src/hooks/`, `src/stores/`; presence of `prisma/` / `drizzle/` / `supabase/` for DB layer; presence of `middleware.ts` for edge logic.
- **Deployment**: presence of `vercel.json` → Vercel; `netlify.toml` → Netlify; `Dockerfile` → containerized; CI workflow targeting `aws s3 sync` → S3 + CloudFront; etc.

### library

- **Install command**: `npm install <name>` / `pnpm add <name>` / `pip install <name>` / `cargo add <name>` / `gem install <name>`. Use the package name from the manifest.
- **Usage section**: Find the public API. For JS/TS, read what's exported from the `main` / `module` / `exports` paths and write a minimal usage example. For Python, find `__all__` in the top-level `__init__.py`. For Rust, look at `pub use` re-exports in `src/lib.rs`.
- **Versioning**: note if there's a `CHANGELOG.md` and link to it; mention semver discipline only if it's clearly being followed.

### cli

- **Install command**: `npm install -g <name>` (Node), `pipx install <name>` or `pip install <name>` (Python), `cargo install <name>` (Rust), `go install <module>@latest` (Go), `brew install <name>` if a Homebrew formula exists.
- **Usage section**: read the help text — often defined in the entry point file as flag descriptions (yargs, commander, click, clap, cobra). Reproduce the main subcommands with one-line descriptions.
- **Examples**: 2–3 representative invocations, not exhaustive.

### api-service

- **Quick start**: clone + install + run the dev server + `curl` the health endpoint (only include the health endpoint if it actually exists in routes).
- **API reference section**: enumerate top-level routes from the routing definitions. Group by resource. Show method + path + one-line description.
- **Architecture**: describe layers (router → controller/handler → service → data), but only if the codebase actually has those layers — don't impose a structure that isn't there.

### native-mobile

- **Quick start**: focus on local-build prerequisites (Xcode version, Android SDK version, Node + RN CLI for React Native, Flutter SDK version for Flutter).
- **Screenshots**: leave a TODO placeholder. v1 doesn't auto-capture from simulators.
- **Deployment**: if `fastlane/` directory exists, mention it; if `.github/workflows/*ios*.yml` or similar exists, mention CI-driven builds; otherwise TODO.

### native-desktop

- **Quick start**: install + dev (e.g., `pnpm tauri dev`).
- **Build**: production build command (e.g., `pnpm tauri build`).
- **Distribution**: if `electron-builder` config exists, note it; if `tauri.conf.json` has bundle targets, list them; otherwise TODO.

---

## Ambiguity resolution

When detection signals conflict:

1. **Next.js inside a monorepo**: the outer monorepo wins; ask the user whether they want a workspace-level README or a per-app README, then re-detect.
2. **A library that also ships a CLI**: type is `cli` (the binary is the headline feature; library usage gets a subsection).
3. **An API that also serves static files**: type is `api-service` (the API is the contract; static file serving is an implementation detail).
4. **A web app with a backend in the same repo**: type is `web-app-browser` (the UI is the user-facing surface; the API gets an Architecture mention).
5. **A library written in TypeScript with a Vitest setup**: still `library` (tests don't change the project type).

When two signals fire at the same scope and the rules above don't resolve cleanly, ask the user. Do not pick arbitrarily — README sections differ enough between types that the wrong choice produces a noticeably worse output.
