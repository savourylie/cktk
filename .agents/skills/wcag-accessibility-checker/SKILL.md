---
name: "wcag-accessibility-checker"
description: "Audit React/Next.js apps for WCAG 2.2 compliance. Use for prompts like check accessibility, run wcag audit, audit a11y, or check WCAG compliance."
---

# WCAG Accessibility Audit

Audit a React/Next.js codebase for WCAG 2.2 conformance using static analysis, optional runtime testing, and manual review. Follow WCAG-EM methodology: define scope, explore target, select sample, audit, report.

## Argument Parsing

Parse any text that follows `$wcag-accessibility-checker`. Support these patterns:

- No arguments: audit the current project at AA level.
- `--level A|AA|AAA`: set the target conformance level. Default: **AA**.
- `--exclude <glob>`: exclude files or routes from the audit.
- `--runtime`: also run `scripts/run_axe.js` for axe-core runtime checks (requires dev server).
- `--route <path>`: limit audit to a specific route or set of routes.

## Step 1 — Define Scope

1. Read `$ARGUMENTS` to determine target level. Default to **AA** if unspecified.
2. Record any exclusions from `$ARGUMENTS`.
3. Detect the framework:

| File/Pattern | Framework |
|-------------|-----------|
| `app/layout.tsx` or `app/page.tsx` | Next.js App Router |
| `pages/_app.tsx` or `pages/_document.tsx` | Next.js Pages Router |
| `createBrowserRouter` or `<Routes>` in source | React Router |
| `remix.config.*` or `app/routes/*.tsx` | Remix |

If no match, search broadly for routing patterns and report the framework as unknown.

## Step 2 — Explore Target

Discover all auditable routes based on the detected framework.

**Next.js App Router:** Find all `page.tsx` / `page.jsx` under `app/`. Note layouts, loading states, and error boundaries.

**Next.js Pages Router:** Find all `*.tsx` / `*.jsx` under `pages/`, excluding `_app`, `_document`, `_error`, and `api/`.

**React Router:** Grep for `path=` in route config files. Trace `<Route>` and `createBrowserRouter` definitions.

Build a route inventory:

```
| # | Route | File | Dynamic? | Layout | Notes |
```

## Step 3 — Select Sample

If the project has more than 20 routes, select a representative sample:

1. Include all unique layouts (at least one route per layout).
2. Include the home/landing page.
3. Include at least one dynamic route.
4. Include at least one form-heavy page.
5. Include at least one data-display page.
6. Prioritize routes with the most interactive elements.

If 20 or fewer routes, audit all of them.

## Step 4 — Audit

Run three audit tracks. The first is required. The second is optional. The third is always performed.

### Track A: Static Analysis (Required)

Run `scripts/scan_codebase.sh` from the skill directory. This checks for:

- `<img>` / `<Image>` without `alt`
- `<input>` without associated `<label>`
- Heading hierarchy gaps
- `onClick` on non-interactive elements without keyboard handlers
- `tabIndex` > 0
- Non-descriptive link text
- `<html>` without `lang`
- `<div>` / `<span>` with `onClick` but no `role` / `tabIndex`

Parse the output. Map each finding to a WCAG success criterion.

### Track B: Runtime Testing (Optional)

Only run if `--runtime` was passed in `$ARGUMENTS`.

Run `scripts/run_axe.js` from the skill directory. This uses axe-core via Playwright to test rendered pages. The dev server must be running.

Parse axe-core results. Map each violation to a WCAG success criterion. Deduplicate against Track A findings.

### Track C: Manual Review (Required)

Read the code for each sampled route. Check against the four POUR principles:

**Perceivable:**
- Text alternatives for all non-text content
- Captions and alternatives for media
- Content adaptable to different presentations
- Sufficient color contrast

**Operable:**
- All functionality available via keyboard
- No keyboard traps
- Sufficient time limits
- No seizure-inducing content
- Clear navigation and focus management

**Understandable:**
- Page language declared
- Predictable navigation and input behavior
- Input error identification and suggestions

**Robust:**
- Valid ARIA usage
- Accessible names and roles on custom widgets
- Status messages programmatically determinable

Read `./references/wcag-criteria.md` for the full criteria reference with common React failure patterns.

## Step 5 — Report

Write the conformance report to `docs/reports/WCAG_AUDIT.md`. Use the template from `./references/report-template.md`.

The report must include:

1. **Executive Summary** — overall conformance status, issue counts by severity and principle.
2. **Scope** — routes audited, exclusions, tools used.
3. **Findings** — organized by WCAG principle, then by success criterion. Each finding includes location, code snippet, impact, and recommended fix.
4. **Criteria With No Issues** — list evaluated criteria that passed.
5. **Prioritized Recommendations** — Critical (fix immediately), Serious (fix soon), Moderate (plan to fix).

Severity mapping:
- **Critical**: Level A violations that block access.
- **Serious**: Level AA violations that significantly impair experience.
- **Moderate**: Level AAA violations or best-practice gaps.

## Behavior Rules

- Report only issues supported by evidence in the code. Do not speculate.
- Deduplicate findings across tracks. If static analysis and axe-core both find the same issue, report it once and note both sources.
- For each finding, provide a concrete code fix, not just a description.
- If `--runtime` was not passed and axe-core was not run, note this in the report scope and recommend running it for contrast and rendered-DOM checks.
- After writing the report, print a summary to the console: total findings, breakdown by severity, and the report file path.
