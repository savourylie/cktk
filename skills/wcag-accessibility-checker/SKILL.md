---
name: wcag-accessibility-checker
description: >
  Audit web applications (React, Next.js) for WCAG 2.2 accessibility compliance using static code
  analysis and automated axe-core testing. Follows the WCAG-EM methodology to produce a structured
  Markdown conformance report organized by WCAG level (A/AA/AAA) and the four POUR principles.
  Use this skill when a user wants to: (1) run a WCAG or accessibility audit on their codebase,
  (2) check React/Next.js components for a11y compliance, (3) generate an accessibility conformance
  report, (4) find and fix accessibility issues in JSX/TSX code, (5) prepare for WCAG compliance
  certification. Do NOT use for: general UI review without accessibility focus, performance audits,
  SEO audits, or accessibility audits of non-web platforms (iOS, Android).
---

# WCAG Accessibility Checker

Dual-approach accessibility audit (static code analysis + automated runtime testing) for React/Next.js applications, following the WCAG-EM evaluation methodology.

## Workflow

1. **Define scope** — determine target WCAG level, framework, pages to audit
2. **Explore target** — discover routes and components
3. **Select sample** — choose representative pages for testing
4. **Audit** — run static analysis + optional axe-core + manual code review
5. **Report** — generate structured Markdown conformance report

---

## Step 1: Define Scope

### Determine target WCAG level

Ask the user which level they're targeting. Default to **AA** (most common regulatory requirement).

| Level | When to use |
|-------|-------------|
| A | Minimum — essential accessibility |
| AA | Recommended — most regulations (ADA, EAA, Section 508) require this |
| AAA | Aspirational — best possible accessibility |

### Detect framework

Check the project root for framework indicators:

| File/Pattern | Framework |
|-------------|-----------|
| `next.config.*` or `app/layout.tsx` | Next.js (App Router) |
| `pages/_app.tsx` or `pages/_document.tsx` | Next.js (Pages Router) |
| `vite.config.*` + React imports | Vite + React |
| `package.json` has `react-scripts` | Create React App |
| `package.json` has `react` | Generic React |

### Identify exclusions

Confirm with the user whether to exclude:
- Third-party components / UI libraries
- Admin-only pages
- Development/debug routes
- Specific directories or files

---

## Step 2: Explore Target / Route Discovery

Discover all user-facing routes based on the framework.

### Next.js App Router

```bash
# Find all page routes
find app -name "page.tsx" -o -name "page.jsx" | sort
# Find all layout files (may contain nav, headers, footers)
find app -name "layout.tsx" -o -name "layout.jsx" | sort
```

### Next.js Pages Router

```bash
find pages -name "*.tsx" -o -name "*.jsx" | grep -v '_app\|_document\|_error\|api/' | sort
```

### React Router

Search for route definitions:

```bash
grep -rnE '<Route\s+.*path\s*=' src/ --include='*.tsx' --include='*.jsx'
```

### Component inventory

Also identify key shared components that appear on many pages:

```bash
# Find component files
find src/components -name "*.tsx" -o -name "*.jsx" 2>/dev/null | sort
# Find common shared UI
grep -rlE '(Navbar|Header|Footer|Sidebar|Modal|Dialog|Toast|Alert)' src/ --include='*.tsx' --include='*.jsx'
```

---

## Step 3: Select Sample

If the project has **fewer than 10 routes**, audit all of them.

For larger projects, select a representative sample covering these categories:

| Category | What to include | Why |
|----------|----------------|-----|
| Home / Landing | Main entry page | First impression, navigation |
| Forms | Login, signup, contact, settings | Input labels, error handling, validation |
| Data display | Tables, lists, dashboards | Data structure, sortable columns |
| Media | Pages with images, video, audio | Alt text, captions, media controls |
| Navigation | Pages with complex nav (menus, breadcrumbs) | Keyboard navigation, focus management |
| Dynamic content | Modals, toasts, accordions, tabs | ARIA roles, live regions, focus traps |
| Error states | 404, error boundaries | Error identification, recovery |

---

## Step 4: Audit

Run two parallel audit tracks, then perform manual review.

### Track A: Static Code Analysis

Run the grep-based scanner on the project:

```bash
bash scripts/scan_codebase.sh <project-root>
```

This outputs JSON with issues for these rules:

| Rule | WCAG SC | What it detects |
|------|---------|-----------------|
| missing-alt | 1.1.1 (A) | `<img>`/`<Image>` without `alt` |
| missing-form-label | 1.3.1 (A) | `<input>`/`<select>`/`<textarea>` without label |
| missing-html-lang | 3.1.1 (A) | `<html>` without `lang` |
| heading-hierarchy | 1.3.1 (A) | Multiple h1s in same file |
| click-without-keyboard | 2.1.1 (A) | `onClick` without keyboard handler on non-button |
| non-semantic-interactive | 4.1.2 (A) | `<div>`/`<span>` with `onClick` but no `role`/`tabIndex` |
| positive-tabindex | 2.4.3 (A) | `tabIndex` > 0 |
| non-descriptive-link | 2.4.4 (A) | Links with "click here", "read more" |
| autoplay-media | 1.4.2 (A) | `<video>`/`<audio>` with autoPlay without muted |
| missing-htmlfor | 1.3.1 (A) | `<label>` without `htmlFor` |

**Important**: The static scanner has limitations (single-line grep patterns). After reviewing its output, manually inspect flagged files for false positives and look for additional issues the scanner cannot detect.

### Track B: Automated Runtime Testing (Optional)

If the user has a dev server running, use axe-core for runtime checks:

```bash
# Install dependencies (one-time)
npm install --no-save @axe-core/playwright playwright
npx playwright install chromium

# Run the scan
node scripts/run_axe.js http://localhost:3000 --urls /,/about,/contact --level AA --output axe-results.json
```

axe-core catches issues that static analysis cannot:
- Color contrast violations (1.4.3, 1.4.6, 1.4.11)
- Missing ARIA attributes at runtime
- Duplicate IDs
- Incorrect ARIA role usage
- Landmarks and region issues
- Focus order problems

If the dev server is not available, note in the report that only static analysis was performed and recommend running axe-core when possible.

### Manual Code Review

After reviewing automated results, manually inspect the sampled routes/components for issues that require human judgment. Read `references/wcag-criteria.md` to understand the full set of criteria.

**Key areas for manual review:**

1. **Perceivable**
   - Are decorative images correctly marked with `alt=""`?
   - Do informational images have meaningful alt text (not just filenames)?
   - Is color used as the sole means of conveying information?
   - Are custom components (modals, tooltips) perceivable to screen readers?

2. **Operable**
   - Can all interactive elements be reached and activated via keyboard?
   - Is focus order logical? Does focus get trapped in modals correctly?
   - Are skip-to-content links present?
   - Is `prefers-reduced-motion` respected for animations?

3. **Understandable**
   - Are form error messages clear and associated with their inputs?
   - Is navigation consistent across pages?
   - Are labels descriptive?

4. **Robust**
   - Do custom widgets have correct ARIA roles and states?
   - Are status messages announced via `aria-live` regions?
   - Is semantic HTML used where possible instead of ARIA?

---

## Step 5: Report

Generate the conformance report using the template.

### Preparation

1. Read `references/report-template.md` for the output structure
2. Read `references/wcag-criteria.md` for criterion descriptions and context
3. Merge results from static analysis, axe-core (if available), and manual review
4. De-duplicate issues found by multiple tools
5. Classify each issue by severity:
   - **Critical** — Level A violations that block access
   - **Serious** — Level AA violations that significantly impair experience
   - **Moderate** — Level AAA violations or best-practice issues

### Report generation

Fill in the template with:
- All findings organized by POUR principle, then by success criterion
- Each finding includes: file/URL, line number, code snippet, impact, and recommended fix
- A list of criteria evaluated with no issues found
- Prioritized recommendations grouped by severity
- Summary statistics (counts by principle, level, severity)

Write the report to a file in the project root (e.g., `wcag-audit-report.md`).

---

## Resources

| Resource | Path | Purpose |
|----------|------|---------|
| WCAG criteria reference | `references/wcag-criteria.md` | All 86 WCAG 2.2 criteria with React failure patterns |
| Report template | `references/report-template.md` | Markdown template for the conformance report |
| Static analyzer | `scripts/scan_codebase.sh` | Grep-based JSX/TSX accessibility checks |
| axe-core runner | `scripts/run_axe.js` | Automated runtime testing via Playwright |

---

## Quick Reference: Common React Accessibility Patterns

### Images

```tsx
// Wrong — missing alt
<img src="/hero.jpg" />
<Image src="/hero.jpg" width={800} height={400} />

// Correct — informational
<img src="/hero.jpg" alt="Team collaborating at a whiteboard" />

// Correct — decorative
<img src="/divider.svg" alt="" role="presentation" />
```

### Interactive elements

```tsx
// Wrong — div with click handler
<div onClick={handleClick}>Submit</div>

// Correct — use semantic HTML
<button onClick={handleClick}>Submit</button>

// If div is unavoidable, add role + keyboard support
<div
  role="button"
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') handleClick(); }}
>
  Submit
</div>
```

### Form inputs

```tsx
// Wrong — no label association
<input type="email" placeholder="Email" />

// Correct — explicit label
<label htmlFor="email">Email</label>
<input id="email" type="email" />

// Correct — aria-label for visually hidden label
<input type="search" aria-label="Search products" />
```

### Focus management

```tsx
// Wrong — removing focus indicator
button:focus { outline: none; }

// Correct — custom focus indicator
button:focus-visible {
  outline: 2px solid #005fcc;
  outline-offset: 2px;
}
```

### Status messages

```tsx
// Wrong — toast without live region
<div className="toast">{message}</div>

// Correct — announced to screen readers
<div role="status" aria-live="polite">{message}</div>

// For urgent messages
<div role="alert" aria-live="assertive">{errorMessage}</div>
```

### Language

```tsx
// Wrong (Next.js)
<Html>

// Correct
<Html lang="en">

// Next.js App Router — in app/layout.tsx
export default function RootLayout({ children }) {
  return <html lang="en">...</html>;
}
```

### Animations

```tsx
// Respect user motion preferences
@media (prefers-reduced-motion: reduce) {
  * { animation: none !important; transition: none !important; }
}

// Or in JS
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
```
