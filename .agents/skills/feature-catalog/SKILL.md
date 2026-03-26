---
name: "feature-catalog"
description: "Generate a structured catalog of user-facing features from a codebase. Use for requests like list features, feature inventory, feature map, audit product capabilities, or what does this app do."
---

# Feature Catalog Generator

Systematically explore a codebase to discover and document user-facing features. Describe what exists from the user's perspective, not how the code is implemented.

## Output Mode

- If the user explicitly invoked `$feature-catalog` or asked for a saved document, write the catalog to `docs/FEATURES.md` unless they gave another path.
- If the user only asked for a quick explanation such as "what does this app do", produce the catalog inline first and mention the default file path you would use for a saved version.

## Step 1: Detect Application Type

Before exploring, determine the application type. Check signals such as:

| Signal | Application Type |
|--------|------------------|
| `next.config.*`, `app/layout.tsx`, `pages/` | Web app (Next.js) |
| `vite.config.*` plus React/Vue/Svelte imports | Web app (SPA) |
| `angular.json` | Web app (Angular) |
| `bin/` entry or `#!/usr/bin/env` shebangs | CLI tool |
| `openapi.*`, `swagger.*`, or routes-only with no UI | API service |
| `android/`, `ios/`, or `react-native.config.js` | Mobile app |
| `electron.*` or `BrowserWindow` entrypoints | Desktop app |
| `manage.py` plus `templates/` | Web app (Django) |
| `Gemfile` plus `app/controllers/` | Web app (Rails) |

Also read repo guidance files such as `AGENTS.md`, `CLAUDE.md`, `README.md`, and the primary package or manifest file if present.

## Step 2: Explore in Layers

Read [exploration-strategies.md](./references/exploration-strategies.md) and work in four passes.

### Layer 1: Entry Points

- Web apps: routes, pages, navigation, tabs, dashboards, settings screens
- CLI tools: commands, subcommands, flags, help text
- APIs: routes, controllers, OpenAPI specs, action names

For each entry point, record the path or command, the title, and the user-facing purpose.

### Layer 2: Component-Level Features

Inside each entry point, identify:

- actions
- data displays
- filters, search, sort, and pagination
- tabs, modals, drawers, or secondary workflows

Look for handler names, forms, button labels, server actions, and conditional UI states.

### Layer 3: Supporting Capabilities

Capture features that span the product:

- authentication and authorization
- notifications and real-time updates
- settings and preferences
- import or export flows
- search and discovery
- background operations users can trigger or observe

### Layer 4: Completeness Sweep

Run a final pass for easy-to-miss features:

1. user-visible strings such as toasts and dialogs
2. feature flags
3. email or notification templates
4. schemas, models, and entity types
5. third-party integrations
6. test names that expose user workflows

## Step 3: Categorize

- Use the app's own terminology when possible.
- Otherwise fall back to categories such as Authentication, Core Features, Data Management, Settings, Notifications, and Administration.
- Aim for 4 to 8 categories.
- Put each feature in exactly one category.

## Step 4: Write the Catalog

When writing a file, use this structure:

```markdown
# Feature Catalog: [Product Name]

> Generated from codebase analysis on [date]
> Application type: [type] ([framework])

## Summary

[1-2 sentences describing what the product does and who it is for.]

**[N] features** across **[M] areas**

## [Category Name]

### [Feature Name]
[1-2 sentence description from the user's perspective.]
```

## Quality Rules

- Describe what users can do, not how the code works.
- Do not propose new features or judge feature quality.
- Mention exploration coverage and any limitations if the scan could not reach a part of the codebase.

