# Codebase Inspection Reference

Systematically discover and analyze an existing codebase to understand what was actually built, not what was specified.

---

## Phase 1: Framework Detection

Check for these indicators in priority order. Stop at first match.

| File/Pattern | Framework |
|-------------|-----------|
| `app/layout.tsx` or `app/page.tsx` | Next.js App Router |
| `pages/_app.tsx` or `pages/_document.tsx` | Next.js Pages Router |
| `nuxt.config.*` and `pages/*.vue` | Nuxt.js |
| `svelte.config.*` and `src/routes/+page.svelte` | SvelteKit |
| `remix.config.*` or `app/routes/*.tsx` | Remix |
| `astro.config.*` and `src/pages/*.astro` | Astro |
| `angular.json` and `*-routing.module.ts` | Angular |
| `src/router/index.ts` with `createRouter` | Vue Router (standalone) |
| `createBrowserRouter` or `<Routes>` in source | React Router |

**If no match:** Search broadly for routing patterns (`route`, `page`, `screen`, `view`) and ask the user to confirm.

**Discovery commands:**

```bash
# Next.js App Router
find app -name "page.tsx" -o -name "page.jsx" -o -name "page.ts" -o -name "page.js" 2>/dev/null
find app -name "layout.tsx" -o -name "layout.jsx" 2>/dev/null

# Next.js Pages Router
find pages -name "*.tsx" -o -name "*.jsx" 2>/dev/null | grep -v "_app\|_document\|_error\|api/"

# React Router
grep -rl "createBrowserRouter\|<Route\|<Routes>" src/ --include="*.tsx" --include="*.jsx" 2>/dev/null

# Nuxt.js / Vue
find pages -name "*.vue" 2>/dev/null
find src/views -name "*.vue" 2>/dev/null

# SvelteKit
find src/routes -name "+page.svelte" 2>/dev/null

# Remix
find app/routes -name "*.tsx" -o -name "*.jsx" 2>/dev/null

# Astro
find src/pages -name "*.astro" 2>/dev/null

# Angular
find src/app -name "*-routing.module.ts" -o -name "*.routes.ts" 2>/dev/null

# Fallback: broad search
find src -name "*.tsx" -o -name "*.jsx" -o -name "*.vue" -o -name "*.svelte" 2>/dev/null | head -50
```

---

## Phase 2: Route Discovery

For the detected framework, enumerate all routes and build an inventory.

**Route inventory table format:**

```markdown
| # | Route Path | File | Type | Dynamic? | Layout | Notes |
|---|-----------|------|------|----------|--------|-------|
| 1 | /         | app/page.tsx | Page | No | RootLayout | Landing page |
| 2 | /dashboard | app/dashboard/page.tsx | Page | No | DashboardLayout | Main dashboard |
| 3 | /users/[id] | app/users/[id]/page.tsx | Page | Yes | RootLayout | User profile |
```

**Type values:** Page, Layout, API (skip reading), Middleware (note only), Error boundary, Loading, Not-found

**For each route, record:**
- Route path (URL the user sees)
- Source file path
- Whether it uses a shared layout (and which one)
- Whether it's dynamic (parameterized)
- Any route guards, middleware, or redirects

**Framework-specific route conventions:**

- **Next.js App Router:** `app/` directory, `page.tsx` = route, `layout.tsx` = layout, `loading.tsx` = loading state, `error.tsx` = error boundary, `[param]` = dynamic, `(group)` = route group (no URL segment)
- **Next.js Pages Router:** `pages/` directory, filename = route, `_app.tsx` = root layout, `[param].tsx` = dynamic
- **React Router:** Routes defined in config or JSX. Grep for `path=` to find route paths. `<Outlet>` = nested layout.
- **Vue/Nuxt:** `pages/` directory, `_param.vue` or `[param].vue` = dynamic, `layouts/` = layouts
- **SvelteKit:** `src/routes/` directory, `+page.svelte` = route, `+layout.svelte` = layout, `[param]` = dynamic
- **Remix:** `app/routes/` directory, filename conventions for nesting, `$param` = dynamic

---

## Phase 3: Layout & Component Analysis

Read these categories of files. For each, extract: purpose, key UI elements, navigation links, states handled.

### 3a. Root Layout(s)
- Global navigation (header, sidebar, footer)
- Authentication wrappers
- Theme/context providers
- Global state management

### 3b. Nested Layouts
- Section-specific navigation (tabs, sub-nav)
- Breadcrumbs
- Section headers
- Sidebar content changes

### 3c. Page Components
For each route's page component, identify:
- Primary content area
- Data fetching patterns (what data is loaded)
- Forms and interactive elements
- Navigation actions (links, buttons that navigate)
- Conditional rendering (role-based, state-based)

### 3d. Shared Components
Search for commonly reused UI components:
```bash
# Find shared component directories
find src/components -name "*.tsx" -o -name "*.jsx" 2>/dev/null
find components -name "*.tsx" -o -name "*.jsx" 2>/dev/null
find src/ui -name "*.tsx" -o -name "*.jsx" 2>/dev/null
```

Focus on: Navigation components (Navbar, Sidebar, Breadcrumb, Tabs), Form components (Input, Select, Modal, Dialog), Feedback components (Toast, Alert, Spinner, Skeleton), Data display (Table, Card, List)

### 3e. State Management
Identify how application state flows:
```bash
# Context providers
grep -rl "createContext\|useContext" src/ --include="*.tsx" --include="*.ts" 2>/dev/null

# State management libraries
grep -rl "useSelector\|useStore\|atom\|create(" src/ --include="*.tsx" --include="*.ts" 2>/dev/null | head -20
```

---

## Phase 4: Implementation Inventory

Assemble findings into a structured summary:

```markdown
## Implementation Inventory

### Navigation Structure
[ASCII sitemap of actual implemented routes]

### Screen Inventory
| Screen | Route | Key Components | Navigation Links | Data Loaded | States Handled |
|--------|-------|---------------|-----------------|-------------|----------------|

### Shared Layout Summary
| Layout | Used By | Contains | Navigation Elements |
|--------|---------|----------|-------------------|

### Component Reuse Map
| Component | Used In | Purpose |
|-----------|---------|---------|
```

---

## Scope Boundaries

**DO inspect:**
- Page/route files
- Layout files (root and nested)
- Shared UI components
- Navigation components
- Form components
- State management (context, stores)
- Error boundaries and loading states
- Client-side routing logic

**DO NOT inspect:**
- API routes / server-side handlers (internal logic, not UX)
- Test files (`*.test.*`, `*.spec.*`, `__tests__/`)
- Build configuration (webpack, vite, next.config internals)
- CI/CD pipelines
- `.pen` files (design files, not code)
- `node_modules/`
- Style-only files (CSS/SCSS without logic) -- note their existence but don't deep-read
- Database models, migrations
- Utility/helper files unless directly related to UI state
