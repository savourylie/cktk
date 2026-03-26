---
name: feature-catalog
user-invocable: true
description: >
  Generate a structured catalog of user-facing features from a codebase. Systematically explores
  routes, components, API endpoints, and configuration to discover what end users can do, then
  produces a categorized Markdown document. Use when a user wants to: (1) list all features in
  a codebase, (2) create a feature inventory or feature map, (3) onboard to an unfamiliar project
  by understanding its capabilities, (4) audit what a product can do for planning or documentation,
  (5) generate product documentation from code. Triggers on: list features, feature inventory,
  what does this app do, feature map, catalog features, feature audit, product capabilities.
  Do NOT use for: generating PRDs, creating tickets, reviewing code quality, or security audits.
---

# Feature Catalog Generator

Systematically explore a codebase to discover and document every user-facing feature,
then produce a structured Markdown catalog organized by functional area.

## The Job

1. Detect the application type and framework
2. Explore the codebase using layered discovery
3. Categorize and describe features from the user's perspective
4. Write the catalog to a Markdown file

**Important:** Document what EXISTS. Do not propose new features, evaluate quality, or suggest improvements.

---

## Step 1: Detect Application Type

Before exploring, determine the application type. Check these indicators:

| Signal | Application Type |
|--------|-----------------|
| `next.config.*`, `app/layout.tsx`, `pages/` | Web app (Next.js) |
| `vite.config.*` + React/Vue/Svelte imports | Web app (SPA) |
| `angular.json` | Web app (Angular) |
| `bin/` entry or `#!/usr/bin/env` shebangs | CLI tool |
| `openapi.*`, `swagger.*`, or routes-only with no UI | API service |
| `android/`, `ios/`, or `react-native.config.js` | Mobile app |
| `electron.config.*`, `main.ts` + `BrowserWindow` | Desktop app |
| `manage.py` + `templates/` | Web app (Django) |
| `Gemfile` + `app/controllers/` | Web app (Rails) |

Also read `CLAUDE.md`, `README.md`, and `package.json` (or equivalent manifest) for
explicit stack descriptions. Note the framework — it determines which exploration
strategies apply.

If the type is ambiguous, ask the user.

---

## Step 2: Explore — Layered Discovery

Explore in four layers. Each layer catches features the previous layers miss.
Read [exploration-strategies.md](./references/exploration-strategies.md) for
detailed framework-specific heuristics.

### Layer 1: Entry Points

Discover all user-accessible entry points — the skeleton of the feature set.

**Web apps:**
- Find all route/page files (e.g., `app/**/page.tsx`, `pages/**/*.tsx`)
- Identify route groups, dynamic segments, catch-all routes
- Exclude API routes, middleware, internal routes
- Read navigation components (navbar, sidebar, tabs) for user-visible structure

**CLI tools:**
- Find command definitions (subcommand registrations, yargs/commander configs)
- Read help text and flag definitions

**APIs:**
- Find all endpoint definitions (route handlers, controller methods)
- Read OpenAPI/Swagger specs if available

For each entry point, record: path/command, title, and brief purpose.

### Layer 2: Component-Level Features

Within each entry point, read the page/screen code to identify interactive capabilities:

- **Actions**: Buttons, forms, links, CTAs — what can the user DO?
- **Data displays**: Tables, charts, lists, cards — what can the user SEE?
- **Controls**: Filters, search, sort, pagination, toggles — how can the user REFINE?
- **State changes**: Modals, drawers, tabs, accordions — what secondary interactions exist?

Look for: event handler names (`onClick`, `onSubmit`, `handleDelete`, `handleExport`),
form actions, server actions, state variables controlling UI modes, conditional rendering.

### Layer 3: Supporting Capabilities

Features not tied to a single page but affecting the user experience:

- **Authentication & authorization**: Login, signup, OAuth, role-based access
- **Notifications**: Toasts, emails, push notifications, real-time updates
- **Background operations**: Syncing, backfills, scheduled tasks users trigger or observe
- **Settings & configuration**: User preferences, account settings, themes
- **Import/export**: Data import, CSV/PDF export, integrations
- **Search**: Global search, in-page search, command palettes

Look in: API routes, middleware, cron handlers, utility libraries, shared hooks.

### Layer 4: Completeness Sweep

Targeted sweep to catch features that are easy to miss:

1. **Grep for user-visible strings** — toast/alert messages, confirmation dialogs reveal actions
2. **Check for feature flags** — `featureFlag`, `isEnabled`, `FF_`, `FEATURE_` reveal gated features
3. **Scan email/notification templates** — reveal communication features
4. **Review database schema or types** — tables/models reveal data entities users interact with
5. **Check third-party integrations** — payment, analytics, social auth, file storage indicate features
6. **Read test descriptions** — tests often name features plainly (e.g., `"user can export posts as CSV"`)

---

## Step 3: Categorize

Group features into functional areas using domain-appropriate categories.

### Category Selection

1. **Use the application's own terminology** — if the nav has "Dashboard", "Analytics",
   "Settings", use those as categories
2. **Fall back to standard categories** when the app lacks clear grouping:
   - Authentication & Account
   - Core [domain] Features
   - Data Management
   - Navigation & Discovery
   - Settings & Preferences
   - Notifications & Communication
   - Administration
3. **Aim for 4-8 categories**
4. **Every feature belongs to exactly one category**

### Feature Description Rules

Write each feature from the user's perspective:

| Wrong (implementation) | Right (user perspective) |
|----------------------|------------------------|
| POST /api/backfill/start endpoint | Start a historical data backfill of past posts |
| useExportCSV hook | Export post data as a CSV file |
| BackfillProgress component with Supabase Realtime | View real-time progress of data imports |
| OAuth callback handler | Sign in with Threads account |

---

## Step 4: Generate Output

Write the catalog to `docs/FEATURES.md` (or a user-specified path).

### Output Template

```markdown
# Feature Catalog: [Product Name]

> Generated from codebase analysis on [date]
> Application type: [type] ([framework])

## Summary

[1-2 sentence description of what this application does and who it is for.]

**[N] features** across **[M] areas**

---

## [Category Name]

### [Feature Name]
[1-2 sentence description from the user's perspective.]

### [Feature Name]
[1-2 sentence description from the user's perspective.]

---

## [Next Category]
...

---

## Coverage Notes

### Explored
- [List of directories/areas that were examined]

### Limitations
- [Any areas that could not be fully analyzed and why]
- [Features behind feature flags or environment-gated logic]
```

### Formatting Rules

- **Product name**: Derive from package.json `name`, README title, or ask the user
- **Feature names**: Short verb-noun phrases ("Export Post Data", "Filter by Date Range")
- **Descriptions**: Always start with what the user can do, not how the code works
- **Order within categories**: Primary features first, supporting features after
- **No code references in output**: The catalog is a product document, not a code map

---

## Checklist

Before delivering the catalog:

- [ ] Application type and framework correctly identified
- [ ] All route/page entry points discovered
- [ ] Navigation components read to confirm user-visible structure
- [ ] Component-level interactions extracted (actions, forms, controls)
- [ ] Supporting capabilities captured (auth, notifications, settings)
- [ ] Completeness sweep performed (strings, flags, schemas, tests)
- [ ] Features described from user perspective, not implementation
- [ ] Categories use application's own terminology where possible
- [ ] 4-8 categories with no orphaned features
- [ ] Output written to docs/FEATURES.md

---

## References

- [Exploration Strategies](./references/exploration-strategies.md) — Framework-specific
  heuristics and grep patterns for each discovery layer
