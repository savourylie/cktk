# Screenshot Capture Strategy

This reference is loaded during Phase 4 of the readme-builder workflow when `screenshots_enabled = true` and the project type is browser-renderable (or a desktop project that agent-browser can capture).

The goal is to produce 3–5 representative PNGs that show what the application looks like, without burning time on flaky setup or fabricating coverage. **A clean failure is better than a misleading screenshot.**

## Table of Contents

1. [The capture loop](#the-capture-loop)
2. [Dev-server discovery](#dev-server-discovery)
3. [Port discovery](#port-discovery)
4. [Waiting for the server](#waiting-for-the-server)
5. [Route selection](#route-selection)
6. [Capture with agent-browser](#capture-with-agent-browser)
7. [Save location and naming](#save-location-and-naming)
8. [Cleanup and failure handling](#cleanup-and-failure-handling)
9. [Native-desktop notes](#native-desktop-notes)

---

## The capture loop

```
1. Discover dev-server command  ──┐
2. Discover port                  ├─► Phase 4a: setup
3. Start server (background)      │
4. Wait for port to respond       │
                                  │
5. Discover routes                ├─► Phase 4b: capture
6. For each route:                │
     navigate → screenshot → save │
                                  │
7. Stop server                    ├─► Phase 4c: cleanup
8. Verify files saved             │
```

If any step in 4a fails, abort the phase cleanly and continue to Phase 5 with a screenshots TODO. If 4b fails mid-capture, save whatever succeeded and TODO the rest.

---

## Dev-server discovery

Check `package.json#scripts` in this order:

1. `dev` — almost universal across modern JS frameworks.
2. `start` — common in CRA, some Express+UI setups; ambiguous (also a production-start script in many projects) — only use if `dev` is absent.
3. `serve` — Vue CLI legacy, some static-site setups.

For Python web apps (Django, Flask, FastAPI with a UI):

- Django: `python manage.py runserver` (if `manage.py` is at the project root).
- Flask: `flask run` (requires `FLASK_APP` env var); only use if `pyproject.toml#[tool.poetry.scripts]` or a `Makefile` target like `dev:` makes this concrete.
- FastAPI: `uvicorn <module>:app --reload` — only construct this if the codebase clearly has a `main.py` or `app.py` exposing `app`.

For Rails: `bin/rails server` (or `rails s`).

For Astro / SvelteKit / Nuxt without a `dev` script (rare), fall back to the framework default: `astro dev`, `vite dev`, `nuxt dev`.

If no dev-server command can be found, do not invent one. Abort the screenshots phase with the reason `no dev-server command detected`.

---

## Port discovery

Check in this order, taking the first match:

1. **Explicit script flag**: parse the dev script body. Common patterns:
   - `next dev -p 4000`
   - `vite --port 4000`
   - `astro dev --port 4000`
   - `npm run dev -- --port 4000`
2. **Framework config**:
   - `next.config.*` — usually 3000 (Next.js doesn't typically take a port in the config).
   - `vite.config.*` — `server.port`.
   - `astro.config.*` — `server.port` or `server: { port }`.
   - `svelte.config.*` — typically uses Vite under the hood; check `vite.config.*` if present.
   - `nuxt.config.*` — `devServer.port`.
3. **Environment variable**: if `.env.example` declares `PORT=...`, use that.
4. **Framework default**:

   | Framework | Default port |
   | --- | --- |
   | Next.js | 3000 |
   | Vite (any) | 5173 |
   | Astro | 4321 |
   | SvelteKit (vite-based) | 5173 |
   | Nuxt | 3000 |
   | CRA | 3000 |
   | Remix | 3000 |
   | Django | 8000 |
   | Rails | 3000 |
   | Flask | 5000 |
   | FastAPI / uvicorn | 8000 |

If the resolved port is in use (detected during the wait step), do not silently fall back to another port — that produces a screenshot of whatever happens to be on the other port. Abort the screenshots phase with the reason `port <N> already in use`.

---

## Waiting for the server

After starting the dev server with `run_in_background: true`, the port won't be ready immediately. Poll until it responds:

```bash
for i in $(seq 1 30); do
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/" | grep -qE "^[2345]"; then
    break
  fi
  sleep 1
done
```

A 30-second budget is enough for almost all modern frameworks on a developer machine. If polling exhausts the budget, treat it as a failure and abort the phase.

Note: a `4xx` response is still "the server is up" — the homepage might 404 by design (e.g., the app's root path is `/app` or `/dashboard`). Accept any 2xx/3xx/4xx as "ready". Only 5xx and connection-refused mean "not ready yet".

---

## Route selection

Aim for 3–5 routes. Defaults:

1. **The root** (`/`) — always include, even if it 404s. The 404 page is itself part of the project's surface.
2. **Up to 4 additional routes** discovered as follows:

### Discovery heuristics

- **Navigation components**: look for files named `Nav*`, `Sidebar*`, `Header*`, `Menu*`, `MainNav*` in `components/`. Read each file and extract route paths from:
  - JSX `<Link href="...">`, `<NavLink to="...">`, `<a href="...">`.
  - Object literals like `{ label: "Dashboard", href: "/dashboard" }`.
- **Route definitions**:
  - Next.js App Router: pages at `app/<route>/page.tsx`.
  - Next.js Pages Router: `pages/<route>.tsx`.
  - Vite + React Router: search for `<Route path="...">`.
  - Astro: pages at `src/pages/<route>.astro`.
  - SvelteKit: `src/routes/<route>/+page.svelte`.

### Filtering

Skip routes that are likely to fail or be misleading:

- **Auth-walled routes** — those behind `/login`, `/auth`, `/account`, `/dashboard` if the project has visible auth setup (next-auth, clerk, lucia, supabase auth, etc.) AND the user has not provided test credentials. Skip these.
- **Dynamic routes with required params** — e.g., `app/posts/[id]/page.tsx`. Skip unless you can identify a specific param value that's known to render (e.g., a seed user ID hinted in `seed.ts` or fixtures). If unsure, skip.
- **API routes** — `app/api/*`, `pages/api/*`. Never include.
- **Catch-all 404 / error / not-found** — `app/not-found.tsx`, `app/error.tsx`. Skip; they're noise.

### Ranking

If more than 4 candidate routes survive filtering, pick the most user-visible:

1. Routes that appear in a top-level navigation component (highest priority).
2. Routes that match common product surfaces: `/`, `/about`, `/pricing`, `/features`, `/blog`, `/docs`, `/contact`, `/faq`, `/dashboard` (if not auth-walled).
3. Routes with shorter paths (less likely to be a sub-flow).

Cap at 4 additional routes. With the root, that's 5 total.

### When no routes can be discovered

For a single-page app with client-side routing and no obvious nav file, capture only `/` and move on. One screenshot is fine — better than two screenshots of the same page with a TODO note.

---

## Capture with agent-browser

Screenshots are taken with the `agent-browser` CLI. Before the first command, load the workflow that matches the installed CLI:

```bash
agent-browser skills get core
```

If `agent-browser` is not on `PATH`, skip Phase 4. TODO: `agent-browser is not installed — add screenshots manually.`

Resolve one session id and pass that same `--session` on every command, including `close`. The unnamed default session is shared with every other agent on the machine.

```bash
SESSION="$(agent-browser session id --scope worktree --prefix readme)"
agent-browser --session "$SESSION" set viewport 1280 800
```

Viewport is `1280×800`. Set it once, before the first `open`.

For each selected route, open the local URL and write a PNG to the path chosen in [Save location and naming](#save-location-and-naming):

```bash
agent-browser --session "$SESSION" open "http://localhost:${PORT}${ROUTE}"
agent-browser --session "$SESSION" screenshot "<save-path>"
```

`open` waits for navigation. If the saved PNG is blank, run `agent-browser --session "$SESSION" wait --load load` once and screenshot that route again. Leave other routes that already saved.

After the last route — and on any failure — close that session:

```bash
agent-browser --session "$SESSION" close
```

---

## Save location and naming

Pick the save directory in this order:

1. If `public/readme/` already exists → use it.
2. Else if `public/` exists AND project is a `web-app-browser` AND framework typically serves `public/` (Next.js, Astro, SvelteKit, Vite) → create and use `public/readme/`. Note in the README that screenshots live in `public/`.
3. Else → create and use `docs/images/`.

**Naming**: slugify the route, with the root path becoming `home`.

| Route | Filename |
| --- | --- |
| `/` | `home.png` |
| `/about` | `about.png` |
| `/blog/posts` | `blog-posts.png` |
| `/users/[id]` (rendered as `/users/42`) | `users-42.png` (use the actual rendered path) |

Always `.png`. The capture commands above already set the viewport to `1280×800`.

---

## Cleanup and failure handling

### Cleanup (the happy path)

After all routes are captured:

1. Identify the background task ID for the dev server.
2. Kill it cleanly. If the dev server didn't capture its own port-cleanup, the user's next `npm run dev` will fail with "port in use" — this is hostile UX, so always stop cleanly.
3. Close the named agent-browser session: `agent-browser --session "$SESSION" close`.

### Failure modes and responses

| Failure | Response |
| --- | --- |
| No dev-server command found | Skip Phase 4. README writes a TODO in the Screenshots section: `TODO: no dev-server command detected — add screenshots manually if applicable.` |
| Port already in use | Stop the (failed) background task. TODO: `Port N already in use — re-run after stopping the conflicting process.` |
| Server never reached 2xx/3xx/4xx within 30s | Stop the background task. TODO: `dev server didn't become ready within 30s — re-run after confirming the dev script works locally.` |
| `agent-browser` not installed | Skip Phase 4. TODO: `agent-browser is not installed — add screenshots manually.` |
| `agent-browser` opens the page but it is blank / errors | Save what was captured of other routes; for the failing route specifically, TODO: `route <path> failed to render — see logs.` |
| One route 404s | That's fine — capture it anyway. A 404 is part of the project's surface. |

In every case, regardless of failure mode, **stop the dev server** and close the named session if one was opened. Leaving a runaway background process for the user to discover is unkind.

---

## Native-desktop notes

### Electron

Load the installed Electron workflow before connecting:

```bash
agent-browser skills get electron
```

Resolve `$SESSION` the same way as in [Capture with agent-browser](#capture-with-agent-browser). Launch the project's existing desktop dev command with the remote-debugging flag from that Electron workflow, then connect and screenshot the main window to the save path from [Save location and naming](#save-location-and-naming):

```bash
agent-browser --session "$SESSION" connect <debug-port>
agent-browser --session "$SESSION" screenshot "<save-path>"
agent-browser --session "$SESSION" close
```

`<debug-port>` is the port the launch actually opened. If the dev command does not start Electron, or `connect` fails, stop whatever you started and leave `TODO: add desktop-app screenshots manually — agent-browser could not attach to the Electron app.`

### Tauri

If `tauri dev` (or the project's dev script) serves the frontend at a known localhost URL, capture that URL with the web flow above. If no frontend URL is known, leave `TODO: add desktop-app screenshots manually — Tauri has no browser URL to capture.`

For iOS / Android / React Native / Flutter — v1 does not attempt automatic capture. The README writes a TODO placeholder and continues. (Future versions could integrate with `xcrun simctl io ... screenshot` or `adb shell screencap`, but those add a lot of moving parts for relatively little gain on first-pass README generation.)
