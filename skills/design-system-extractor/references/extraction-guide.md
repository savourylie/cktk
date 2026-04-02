# Extraction Guide

Heuristics for identifying design elements from UI screenshots.

## Table of Contents

1. [Color Extraction](#color-extraction)
2. [Typography Extraction](#typography-extraction)
3. [Spacing Extraction](#spacing-extraction)
4. [Border Radius Extraction](#border-radius-extraction)
5. [Shadow Extraction](#shadow-extraction)
6. [Component Pattern Extraction](#component-pattern-extraction)
7. [Layout Extraction](#layout-extraction)
8. [Dark Mode Detection](#dark-mode-detection)

## Color Extraction

### Where to look

| UI Element | Token category |
|---|---|
| Large filled buttons, nav highlights, links | `color.primary` |
| Hover/active variants of primary elements | `color.primary-light`, `color.primary-dark` |
| Secondary buttons, tags, badges | `color.secondary` |
| Small highlights, toggles, active indicators | `color.accent` |
| Main page area behind content | `color.background` |
| Cards, modals, elevated panels | `color.surface` |
| Headings, main body text | `color.text-primary` |
| Descriptions, metadata, timestamps | `color.text-secondary` |
| Placeholders, disabled labels | `color.text-tertiary` |
| Card edges, input outlines, dividers | `color.border` |
| Error banners, destructive buttons, form errors | `color.error` |
| Warning badges, caution messages | `color.warning` |
| Success toasts, checkmarks, positive indicators | `color.success` |

### Heuristics

- Primary color is usually the most prominent saturated color — used for CTAs and links
- If only one saturated color is visible, it is `primary`; the second most-used is `secondary`
- Background vs surface: background is the outermost layer; surface is cards/panels layered on top
- Text colors typically come in 2-3 shades — darkest for headings, medium for body, lightest for captions
- Border colors are almost always a light gray — look at card edges and input outlines
- Status colors (error/warning/success) often appear in alerts, form validation, or badges

### Common pitfalls

- Don't confuse image/illustration colors with UI token colors
- Gradient backgrounds: extract the dominant color and note it's a gradient
- Transparent overlays: note the underlying color, not the blended result

## Typography Extraction

### Font family identification

- **Geometric sans-serifs** (circular 'o', even stroke): Inter, Helvetica Neue, SF Pro, Circular, Outfit
- **Humanist sans-serifs** (varying stroke width): Open Sans, Source Sans, Lato, Nunito
- **Neo-grotesque** (neutral, uniform): Roboto, Arial, Helvetica
- **Display/brand fonts** (distinctive features): Plus Jakarta Sans, Manrope, Satoshi, General Sans
- **Monospace** (equal character width): JetBrains Mono, Fira Code, SF Mono, Source Code Pro
- **Serif** (decorative strokes): Georgia, Merriweather, Playfair Display, Lora

If uncertain, note the visual characteristics and provide the closest match with a confidence level.

### Font size scale

Look for these common text roles to establish the scale:

| Role | Typical size range |
|---|---|
| Tiny labels, badges | 10-12px |
| Captions, metadata | 12-13px |
| Body text, descriptions | 14-16px |
| Subheadings, lead text | 18-20px |
| Section headings | 24-30px |
| Page titles | 32-48px |
| Hero text | 48-72px |

Infer approximate sizes by comparing text elements relative to each other and to known UI conventions.

### Font weight

- **Regular (400)**: body text, descriptions
- **Medium (500)**: labels, navigation items, slightly emphasized text
- **Semibold (600)**: subheadings, button text, table headers
- **Bold (700)**: headings, hero text, strong emphasis

### Line height

- **Tight (1.2-1.3)**: headings, display text
- **Normal (1.4-1.6)**: body text, paragraphs
- **Relaxed (1.7-1.8)**: long-form reading, documentation

### Font source resolution

After identifying each font family, determine the source URL so the applier can load the font:

1. **Check if it's a system font** — these don't need imports:
   - SF Pro, SF Mono, Helvetica Neue, Helvetica, Arial, Georgia, Times New Roman, Courier New, system-ui, -apple-system, BlinkMacSystemFont
   - Set the `font-source` value to `"system"` for these

2. **Construct a Google Fonts URL** for web fonts — most non-system fonts used on the web come from Google Fonts:
   - Base URL: `https://fonts.googleapis.com/css2?family=`
   - Replace spaces in the font name with `+` (e.g., `Plus Jakarta Sans` → `Plus+Jakarta+Sans`)
   - Append only the weights that were actually extracted: `wght@400;500;600;700`
   - Always include `&display=swap` for better loading performance
   - Example: `https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap`

3. **Common Google Fonts by category:**
   - Geometric sans: Inter, Outfit, DM Sans, Nunito Sans, Poppins
   - Humanist sans: Open Sans, Source Sans 3, Lato, Nunito
   - Display/brand: Plus Jakarta Sans, Manrope, Satoshi, General Sans, Space Grotesk
   - Monospace: JetBrains Mono, Fira Code, Source Code Pro, IBM Plex Mono, Roboto Mono
   - Serif: Merriweather, Playfair Display, Lora, Libre Baskerville, IBM Plex Serif

4. **If the font is not on Google Fonts** (e.g., Satoshi, General Sans from Fontshare), note the source and use the best available URL. When unsure, default to the Google Fonts URL pattern and annotate with a confidence marker.

## Spacing Extraction

### Inferring the base unit

Most design systems use a 4px or 8px base unit. Look at:

- Padding inside buttons (commonly 8-12px vertical, 16-24px horizontal)
- Gap between form labels and inputs (commonly 4-8px)
- Gap between list items (commonly 8-16px)
- Card inner padding (commonly 16-24px)
- Section spacing (commonly 32-64px)

If values cluster around multiples of 4: base unit is 4px.
If values cluster around multiples of 8: base unit is 8px.

### Building the scale

Once you identify the base unit, list the full scale you observe:

- 4px base: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96
- 8px base: 8, 16, 24, 32, 48, 64, 96

Only include values you can actually observe or reasonably infer from the screenshots.

## Border Radius Extraction

### Where to look

| Element | Typical radius |
|---|---|
| Small buttons, badges, tags | 4px (sm) |
| Standard buttons, cards, inputs | 6-8px (md) |
| Large cards, modals, panels | 12-16px (lg) |
| Feature cards, hero sections | 16-24px (xl) |
| Avatars, pills, chips | 9999px (full) |

### Heuristics

- If corners look barely rounded: 2-4px
- If corners are noticeably rounded but not circular: 6-12px
- If corners are very round: 16-24px
- If elements are pill-shaped or circular: 9999px (full)
- Many modern UIs use a consistent radius (often 8px) across most elements

## Shadow Extraction

### Visual depth levels

| Level | Visual cue | Typical CSS |
|---|---|---|
| None | Flat, no depth | none |
| sm | Subtle lift, barely visible | `0 1px 2px rgba(0,0,0,0.05)` |
| md | Clear card elevation | `0 4px 6px rgba(0,0,0,0.07)` |
| lg | Dropdown/popover depth | `0 10px 15px rgba(0,0,0,0.1)` |
| xl | Modal/dialog depth | `0 20px 25px rgba(0,0,0,0.15)` |

### Heuristics

- Cards typically use sm or md shadows
- Dropdowns and popovers use lg shadows
- Modals and dialogs use xl shadows
- If no shadows are visible, the design may use borders instead for depth — note this

## Component Pattern Extraction

Identify these common components and their styles:

### Buttons
- Fill style: solid, outline, ghost, link
- Sizes: how many size variants visible?
- States: default, hover, disabled (if visible)
- Icon usage: leading icon, trailing icon, icon-only

### Cards
- Border: solid, subtle, or none?
- Shadow level
- Padding consistency
- Header/body/footer structure

### Inputs
- Border style: full border, bottom-only, or filled background?
- Focus indicator color (usually primary)
- Label position: above, inline, floating
- Error state styling (if visible)

### Navigation
- Style: top bar, sidebar, bottom tabs
- Active indicator: underline, background fill, color change, bold text
- Layout structure

## Layout Extraction

- **Max content width**: estimate from the widest content area (commonly 1200px, 1280px, or 1440px)
- **Grid**: count columns if visible — 12-column is standard; some use 2/3/4 column layouts
- **Responsive clues**: if multiple screenshots show different viewport widths, note breakpoints

## Dark Mode Detection

If the screenshot shows a dark theme:
- Note it in the `meta` section
- Background/surface colors will be dark grays/blacks
- Text colors will be light/white
- Primary color may shift slightly for contrast on dark backgrounds
- Consider noting both dark theme tokens and suggested light-mode counterparts if obvious
