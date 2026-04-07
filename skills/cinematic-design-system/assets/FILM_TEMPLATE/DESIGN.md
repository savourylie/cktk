# Design System Inspiration of [Film]

<!--
TEMPLATE — FILM_TEMPLATE/DESIGN.md, used by the cinematic-design-system skill
in Phase 3 to back-derive a design system from a locked UX_DESIGN.md.

Derived from cinematic-ui/BRAND_TEMPLATE with "brand" renamed to "film" at
every source-reference point. The term "brand color" is preserved wherever
it names the CTA-color role — that's a design-systems term of art that holds
whether the source is a brand or a film.

Fill in every section. Replace bracketed placeholders. Delete unused optional
H3s. The cinematic-design-system skill writes this file to `docs/DESIGN.md`.

Conventions:
- Title is always: "# Design System Inspiration of [Film]"
- 9 H2 sections in the order below — never reorder, never skip
- Hex codes always wrapped in backticks: `#0071e3`
- Font names in backticks; CSS variable names in backticks
- No YAML front matter, no images, no footer
- Typical length: 200-350 lines

Do not expose film title, director name, or workflow metadata (chapter,
calibrated, treatment, report build) inside the user-facing CSS tokens.
Those live in `docs/RESEARCH.md` and `docs/UX_DESIGN.md`, not here.
-->

## 1. Visual Theme & Atmosphere

<!--
Format: 2-4 prose paragraphs, then a "**Key Characteristics:**" bulleted list of
7-10 concrete traits. No H3 sub-headings here — this section is narrative.

Capture in the prose:
- Overall mood / sensory impression (e.g. "cinematic", "command center", "radical minimalism")
- Primary design philosophy (derived from the film's visual grammar)
- Signature typography approach and what it conveys
- Color story (dominant hues, accent strategy — sourced from actual film scenes)
- How visual hierarchy is achieved (photography, contrast, spacing, density)
- Notable technical approach (shadows, blur, overlays, motion)

Key Characteristics bullets should be specific and actionable: include hex codes,
font names, radius values, and design principles — not vague adjectives.
-->

[Opening paragraph: the dominant visual mood and what it communicates.]

[Second paragraph: the philosophy or constraint that drives the design — why it
looks this way, not just how.]

[Optional third/fourth paragraph: signature techniques (typographic, color,
spatial) that make the design feel film-authentic.]

**Key Characteristics:**
- [Concrete trait, e.g. "Geist Sans with -2.4px letter-spacing at display sizes"]
- [Concrete trait, e.g. "Pure white `#ffffff` canvas with `#0071e3` as the only CTA color"]
- [Concrete trait, e.g. "8px base spacing unit, 12px container radius"]
- [Add 4-7 more]

## 2. Color Palette & Roles

<!--
Format: H3 groups; each group is a bulleted list. Bullet shape:
  - **Color Name** (`#hex`): css-var-or-token-name. Role description. Usage context.

Universal H3s (Primary, Surface & Background, Neutrals & Text) are stubbed below
— fill them in. Optional H3s, add only if the film warrants them:
  ### Interactive            — link / focus / hover colors as a distinct group
  ### Semantic               — error, success, warning, info
  ### Shadows                — shadow color tokens (often rgba)
  ### Gradients              — explicit gradient tokens (many films have none)
  ### Film-specific          — e.g. "Blade Runner Orange", "Stalker Sepia" as their own group

Wide-gamut colors are fine: `color(display-p3 .27 1 0)` is acceptable.
-->

### Primary
- **[Primary Color Name]** (`#hex`): `--token-name`. Primary brand color. CTA backgrounds, link text, focus highlights.
- **[Secondary]** (`#hex`): `--token-name`. Role. Usage.

### Surface & Background
- **[Page Background]** (`#hex`): `--bg-page`. Default canvas.
- **[Elevated Surface]** (`#hex`): `--bg-surface`. Cards, panels, modal backgrounds.
- **[Muted Surface]** (`#hex`): `--bg-muted`. Subtle background blocks, code blocks.

### Neutrals & Text
- **[Heading]** (`#hex`): `--text-primary`. Headlines, high-emphasis copy.
- **[Body]** (`#hex`): `--text-secondary`. Body paragraphs, descriptions.
- **[Muted]** (`#hex`): `--text-tertiary`. Captions, metadata, disabled state.
- **[Border]** (`#hex`): `--border-default`. Hairlines, dividers, input borders.

## 3. Typography Rules

### Font Family

<!--
Bullet format. Always include fallbacks. Mention OpenType features only if the
typography direction calls for them (ss01, tnum, liga, calt, cv01, etc.).
-->

- **Primary**: `Font Name`, with fallbacks: `system-ui, -apple-system, "Segoe UI", ...`
- **Monospace**: `Mono Font Name`, with fallbacks: `ui-monospace, SFMono-Regular, ...`
- **OpenType Features**: `"ss01"`, `"tnum"` enabled globally (omit this line if none)

### Hierarchy

<!--
Markdown table. Columns are fixed. Typical row count: 12-20. Order rows from
largest (Display Hero) to smallest (Micro / Caption). Sizes shown as `px (rem)`.
Letter spacing in px (negative for tight tracking).
-->

| Role           | Font          | Size           | Weight | Line Height | Letter Spacing | Notes                          |
|----------------|---------------|----------------|--------|-------------|----------------|--------------------------------|
| Display Hero   | [Font]        | 56px (3.50rem) | 600    | 1.07        | -0.28px        | Hero headlines, max impact     |
| Display Large  | [Font]        | 48px (3.00rem) | 600    | 1.10        | -0.96px        | Section headlines              |
| Heading 1      | [Font]        | 32px (2.00rem) | 600    | 1.20        | -0.32px        | Page H1                        |
| Heading 2      | [Font]        | 24px (1.50rem) | 600    | 1.25        | -0.24px        | Section H2                     |
| Heading 3      | [Font]        | 20px (1.25rem) | 500    | 1.30        | -0.20px        | Sub-section headings           |
| Body Large     | [Font]        | 18px (1.13rem) | 400    | 1.55        | normal         | Lead paragraphs                |
| Body           | [Font]        | 16px (1.00rem) | 400    | 1.50        | normal         | Default paragraph text         |
| Body Small     | [Font]        | 14px (0.88rem) | 400    | 1.50        | normal         | Secondary copy, labels         |
| Caption        | [Font]        | 12px (0.75rem) | 400    | 1.40        | 0.12px         | Metadata, footnotes            |
| Code / Mono    | [Mono Font]   | 14px (0.88rem) | 400    | 1.55        | normal         | Inline code, code blocks       |
| Button         | [Font]        | 15px           | 500    | 1.00        | normal         | All button labels              |

### Principles

<!-- 3-6 bullets capturing the typography philosophy. Be specific. -->

- [e.g. "Weight 300 at display sizes is the film's most distinctive typographic choice"]
- [e.g. "Letter-spacing scales negatively with size: tighter at display, normal at body"]
- [e.g. "Monospace is used for credentials, IDs, and technical metadata — never decoratively"]

## 4. Component Stylings

<!--
Per-component prose with property bullets. NOT tables. Buttons always come first.
Universal sub-sections (in order): Buttons → Cards & Containers → Inputs & Forms → Navigation.
Optional sub-sections (add only if the film warrants a notable treatment):
  ### Image Treatment        — photography standards, aspect ratios, lazy loading, art direction
  ### Modals                 — overlay backdrop, dismiss patterns
  ### Badges                 — pills, status chips
  ### Tabs                   — underline vs filled, active state
  ### Distinctive Components — anything signature: hero modules, command palettes, pipelines, carousels
-->

### Buttons

<!-- Document each variant the film's visual language warrants. Always include
     all 3 standard variants (Primary, Secondary, Tertiary/Ghost) if they exist.
     Per variant, list every property an implementer would need to recreate it
     pixel-perfect. -->

**Primary**
- Background: `#hex`
- Text: `#hex`
- Padding: 12px 20px
- Radius: 8px
- Border: `1px solid transparent` (or specify)
- Font: [Font], 15px, weight 500
- Hover: [describe — bg shift, transform, shadow]
- Active: [describe]
- Focus: [outline / ring details, e.g. `0 0 0 3px rgba(...)`]
- Disabled: [opacity / color shift]
- Use: [primary CTA, hero, signup]

**Secondary**
- Background: `#hex`
- Text: `#hex`
- Border: `1px solid #hex`
- Hover: ...
- Use: ...

**Tertiary / Ghost**
- Background: `transparent`
- Text: `#hex`
- Hover: ...
- Use: ...

### Cards & Containers

- Background: `#hex`
- Border: `1px solid #hex` (or specify shadow-as-border treatment)
- Radius: [e.g. 12px]
- Padding: [e.g. 24px]
- Shadow: [hex/rgba shadow value, or "none — uses border only"]
- Hover state: [e.g. lift, glow, border color shift, or "none — static"]

### Inputs & Forms

- Background: `#hex`
- Border: `1px solid #hex`
- Radius: [e.g. 6px]
- Padding: [e.g. 10px 14px]
- Font: [Font], [size], weight 400
- Placeholder color: `#hex`
- Label: [position, font, color]
- Focus state: [border color, ring, shadow]
- Error state: [border color, helper text color]

### Navigation

- Background: `#hex` (or `rgba(...)` with backdrop blur)
- Height: [px]
- Logo: [size, treatment]
- Link styling: [font, size, weight, color, hover]
- Sticky / overlay behavior: [describe]
- Mobile breakpoint: [collapses at Xpx into hamburger / drawer / etc.]

## 5. Layout Principles

### Spacing System

<!-- Bullets or table — both formats are acceptable. Always state the base
     unit and the full scale. -->

- **Base unit**: 8px (or whatever the film's rhythm warrants)
- **Scale**: 4px, 8px, 12px, 16px, 24px, 32px, 48px, 64px, 96px, 128px
- **Section padding**: [vertical rhythm between major sections]
- **Component padding**: [internal padding standards]

### Grid & Container

- **Max content width**: [e.g. 1200px]
- **Gutter**: [e.g. 24px desktop, 16px mobile]
- **Column system**: [e.g. 12-column desktop, single-column mobile]
- **Hero layout**: [centered single-column, asymmetric, full-bleed, etc.]

### Whitespace Philosophy

<!-- 1-2 prose paragraphs explaining HOW whitespace communicates in this film's
     aesthetic. This is conceptual, not tabular. -->

[Paragraph: how generous or compact the layout is, what the whitespace
communicates, how section rhythm is established.]

### Border Radius Scale

- **0px** (sharp): [usage — e.g. "tables, code blocks", or "never"]
- **4px** (subtle): [usage — e.g. "inputs, small badges"]
- **8px** (default): [usage — e.g. "buttons, small cards"]
- **12px** (comfortable): [usage — e.g. "cards, panels"]
- **9999px** (pill): [usage — e.g. "tags, avatars, toggle switches"]

## 6. Depth & Elevation

<!--
Markdown table. Columns are fixed: Level | Treatment | Use. Typical row count: 3-6.
Treatments are CSS-ready: actual shadow strings, border definitions, or backdrop filters.
After the table, add a "**Shadow Philosophy:**" prose block (2-4 paragraphs) explaining
the film's stance on depth (flat, layered, shadow-as-border, blur-driven, etc.).
-->

| Level                  | Treatment                                                       | Use                                          |
|------------------------|-----------------------------------------------------------------|----------------------------------------------|
| Flat (Level 0)         | No shadow, solid background                                     | Page sections, text blocks                   |
| Ring (Level 1)         | `rgba(0,0,0,0.08) 0px 0px 0px 1px`                              | Shadow-as-border for cards / inputs          |
| Subtle Lift (Level 2)  | `rgba(0,0,0,0.06) 0px 4px 12px -2px`                            | Hovered cards, dropdowns                     |
| Floating (Level 3)     | `rgba(0,0,0,0.12) 0px 12px 32px -8px`                           | Modals, popovers, command palette            |
| Glass (Level Nav)      | `backdrop-filter: saturate(180%) blur(20px)` on `rgba(255,255,255,0.8)` | Sticky navigation bar |

**Shadow Philosophy:**

[Paragraph: how this film's world handles depth. Multi-layer Material-style? Flat?
Shadow-as-border? Color-tinted shadows? Why.]

[Optional second paragraph: technical rationale or decorative depth techniques
beyond shadows — gradients, blur, overlays, photographic depth. This is where
the film's *material thesis* lands in the design system.]

<!-- Optional H3:
### Decorative Depth
Non-shadow techniques: gradient overlays, atmospheric blur, photographic layering. -->

## 7. Do's and Don'ts

<!--
Default format: two bullet lists — "### Do" then "### Don't", 7-15 items each.
Be prescriptive and specific. This is where the film's *restraint statement*
from UX_DESIGN.md becomes actionable rules.

Variant: replace with one of these alternatives only if it really matters more
than dos/donts for this film:
  ### Interaction & Motion   — entrance/hover/exit transitions, easing curves
  ### Dark Mode              — light↔dark token mappings
  ### Accessibility & States — focus / error / loading state guidance
-->

### Do
- [Prescriptive rule with concrete value, e.g. "Use weight 300 for all headlines and body — lightness is the signature"]
- [e.g. "Apply blue-tinted shadows `rgba(50,50,93,0.25) 0px 50px 100px -20px` to elevated elements"]
- [e.g. "Stick to the 8px spacing scale — never use ad-hoc values like 7px or 11px"]
- [Add 4-12 more]

### Don't
- [Negation with reason, e.g. "Don't scatter the brand color across the interface — it's a CTA signal, not a theme"]
- [e.g. "Don't add box-shadows to content cards — depth comes from background contrast, not elevation"]
- [e.g. "Don't use rounded-pill buttons — the 8px radius is non-negotiable"]
- [Add 4-12 more]

## 8. Responsive Behavior

### Breakpoints

<!-- Markdown table. Columns are fixed: Name | Width | Key Changes. Typical: 4-6 rows. -->

| Name          | Width            | Key Changes                                                              |
|---------------|------------------|--------------------------------------------------------------------------|
| Mobile        | <640px           | Single column, hamburger nav, stacked hero, font scale -1 step           |
| Tablet        | 640px – 1024px   | 2-column grids, condensed nav, hero retains layout                       |
| Desktop       | 1024px – 1440px  | Full layout, max content width, multi-column grids                       |
| Large Desktop | >1440px          | Wider gutters, larger hero imagery, no further reflow                    |

### Touch Targets

- Minimum size: 44 x 44px (iOS HIG standard)
- Spacing between adjacent targets: at least 8px
- Primary CTAs: full-width on mobile, auto-width on tablet+

### Collapsing Strategy

- **Navigation**: [horizontal links → hamburger / drawer at Xpx]
- **Hero**: [side-by-side text+image → stacked single column]
- **Multi-column sections**: [3-col → 2-col → 1-col cascade]
- **Tables**: [horizontal scroll vs reflow to cards]

<!-- Optional H3s:
### Image Behavior
- Aspect ratio handling, art direction, lazy loading
### Typography Scaling
- How the type scale shifts at each breakpoint
-->

## 9. Agent Prompt Guide

### Quick Color Reference

<!-- Either a fenced code block or a bullet list. The fenced form is easier for
     agents to copy. Include the 6-10 most important hex codes. -->

```
Background:    #hex   (page canvas)
Surface:       #hex   (elevated cards / panels)
Primary CTA:   #hex   (brand color, action buttons)
Heading text:  #hex   (high-emphasis copy)
Body text:     #hex   (default paragraph)
Border:        #hex   (hairlines, input borders)
```

### Example Component Prompts

<!-- 2-5 ready-to-paste prompts. Each one should be specific enough that an
     agent can produce a pixel-accurate result with no further context. Include
     hex codes, font specs, padding, and state behavior in each prompt. -->

- "Create a hero section on `#hex` background. Headline at 56px [Font] weight 600,
  line-height 1.07, letter-spacing -0.28px, color `#hex`. Sub-headline at 18px
  weight 400, line-height 1.55, color `#hex`. Primary CTA: `#hex` background,
  white text, 12px 20px padding, 8px radius, hover lifts -1px with shadow
  `rgba(0,0,0,0.12) 0px 8px 24px -4px`."

- "Build a feature card on `#hex` surface. 24px padding, 12px radius, border
  `1px solid #hex`. Title 20px weight 500, body 16px weight 400 line-height 1.5.
  Hover: border color shifts to `#hex`, no transform."

- "[Add 1-3 more covering nav, form, list, modal, etc.]"

### Iteration Guide

<!-- Numbered list of build/refine steps an agent should follow when generating
     UI in this style. 5-10 steps. Order matters — earliest steps establish the
     foundation, later steps refine. -->

1. [e.g. "Set the page background to `#hex` and load [Font] as the default family"]
2. [e.g. "Apply the 8px spacing scale globally — every margin and padding must be a multiple"]
3. [e.g. "Use shadow-as-border for all elevated surfaces — never use a CSS border"]
4. [e.g. "Letter-spacing scales negatively with font size: -2.4px at 48px, -1.28px at 32px, -0.28px at 16px"]
5. [e.g. "Reserve the brand color `#hex` for primary CTAs only — never use it for text or decoration"]
6. [Add 2-5 more]
