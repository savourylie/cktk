# Example Output

A complete example of an extracted design system from a hypothetical SaaS dashboard screenshot.

---

# Design System: Acme Dashboard

Extracted from: screenshot of Acme Analytics dashboard (acme-dashboard.png)
Generated: 2026-02-23

## Color Tokens

| Token | Hex | Usage |
|-------|-----|-------|
| color.primary | #2563EB | Primary buttons, active nav items, links |
| color.primary-light | #60A5FA | Hover states, selected backgrounds |
| color.primary-dark | #1D4ED8 | Pressed button states |
| color.secondary | #7C3AED | Tags, badges, secondary actions |
| color.accent | #F59E0B | Highlighted metrics, star ratings |
| color.background | #F9FAFB | Page background |
| color.surface | #FFFFFF | Cards, panels, modals |
| color.text-primary | #111827 | Headings, body text |
| color.text-secondary | #6B7280 | Descriptions, metadata, timestamps |
| color.text-tertiary | #9CA3AF | Placeholder text, disabled labels |
| color.border | #E5E7EB | Card borders, input outlines, dividers |
| color.border-light | #F3F4F6 | Subtle separators |
| color.error | #EF4444 | Error badges, destructive buttons |
| color.warning | #F59E0B | Warning indicators |
| color.success | #10B981 | Positive metrics, success badges |
| color.info | #3B82F6 | Info banners |

## Typography

| Token | Value | Usage |
|-------|-------|-------|
| font.family.heading | "Inter", sans-serif | All headings |
| font.family.body | "Inter", sans-serif | Body text, labels |
| font.family.mono | "JetBrains Mono", monospace | Code snippets, metric values |
| font.size.xs | 12px | Badges, tiny labels |
| font.size.sm | 14px | Body text, table cells |
| font.size.base | 16px | Lead text, form labels |
| font.size.lg | 18px | Card headings |
| font.size.xl | 20px | Section headings |
| font.size.2xl | 24px | Page subtitles |
| font.size.3xl | 30px | Page titles |
| font.size.4xl | 36px | Dashboard hero metrics |
| font.weight.regular | 400 | Body text |
| font.weight.medium | 500 | Labels, nav items |
| font.weight.semibold | 600 | Subheadings, buttons |
| font.weight.bold | 700 | Page titles, hero metrics |
| font.line-height.tight | 1.25 | Headings |
| font.line-height.normal | 1.5 | Body text |
| font.line-height.relaxed | 1.75 | Long descriptions |
| font.source.heading | https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap | Font loading for headings |
| font.source.body | https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap | Font loading for body |
| font.source.mono | https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&display=swap | Font loading for code |

## Spacing Scale

| Token | Value |
|-------|-------|
| space.1 | 4px |
| space.2 | 8px |
| space.3 | 12px |
| space.4 | 16px |
| space.5 | 20px |
| space.6 | 24px |
| space.8 | 32px |
| space.10 | 40px |
| space.12 | 48px |
| space.16 | 64px |

Base unit: 4px

## Border Radius

| Token | Value |
|-------|-------|
| radius.sm | 4px |
| radius.md | 8px |
| radius.lg | 12px |
| radius.xl | 16px |
| radius.full | 9999px |

## Shadows

| Token | Value |
|-------|-------|
| shadow.sm | 0 1px 2px rgba(0,0,0,0.05) |
| shadow.md | 0 4px 6px -1px rgba(0,0,0,0.07) |
| shadow.lg | 0 10px 15px -3px rgba(0,0,0,0.1) |
| shadow.xl | 0 20px 25px -5px rgba(0,0,0,0.1) |

## Component Patterns

| Component | Styles |
|-----------|--------|
| Button (primary) | Solid fill, #2563EB bg, white text, 8px radius, 12px/24px padding, 600 weight |
| Button (secondary) | Outline, 1px #E5E7EB border, #111827 text, 8px radius |
| Button (ghost) | No border/bg, #2563EB text, hover: #F0F5FF bg |
| Card | White bg, 1px #E5E7EB border, 12px radius, 24px padding, sm shadow |
| Input | White bg, 1px #E5E7EB border, 8px radius, 12px/16px padding, focus: #2563EB border |
| Badge | 4px radius, 4px/8px padding, 12px font, semibold |
| Nav item | 500 weight, 14px, #6B7280 text, active: #2563EB text + #EFF6FF bg, 8px radius |

## Design Tokens (JSON)

```json
{
  "meta": {
    "name": "Acme Dashboard Design System",
    "source": "Screenshot of Acme Analytics dashboard",
    "version": "1.0.0",
    "generated": "2026-02-23"
  },
  "color": {
    "primary": { "value": "#2563EB", "type": "color" },
    "primary-light": { "value": "#60A5FA", "type": "color" },
    "primary-dark": { "value": "#1D4ED8", "type": "color" },
    "secondary": { "value": "#7C3AED", "type": "color" },
    "accent": { "value": "#F59E0B", "type": "color" },
    "background": { "value": "#F9FAFB", "type": "color" },
    "surface": { "value": "#FFFFFF", "type": "color" },
    "text-primary": { "value": "#111827", "type": "color" },
    "text-secondary": { "value": "#6B7280", "type": "color" },
    "text-tertiary": { "value": "#9CA3AF", "type": "color" },
    "border": { "value": "#E5E7EB", "type": "color" },
    "border-light": { "value": "#F3F4F6", "type": "color" },
    "error": { "value": "#EF4444", "type": "color" },
    "warning": { "value": "#F59E0B", "type": "color" },
    "success": { "value": "#10B981", "type": "color" },
    "info": { "value": "#3B82F6", "type": "color" }
  },
  "typography": {
    "font-family-heading": { "value": "'Inter', sans-serif", "type": "fontFamily" },
    "font-family-body": { "value": "'Inter', sans-serif", "type": "fontFamily" },
    "font-family-mono": { "value": "'JetBrains Mono', monospace", "type": "fontFamily" },
    "font-size": {
      "xs": { "value": "12px", "type": "dimension" },
      "sm": { "value": "14px", "type": "dimension" },
      "base": { "value": "16px", "type": "dimension" },
      "lg": { "value": "18px", "type": "dimension" },
      "xl": { "value": "20px", "type": "dimension" },
      "2xl": { "value": "24px", "type": "dimension" },
      "3xl": { "value": "30px", "type": "dimension" },
      "4xl": { "value": "36px", "type": "dimension" }
    },
    "font-weight": {
      "regular": { "value": "400", "type": "fontWeight" },
      "medium": { "value": "500", "type": "fontWeight" },
      "semibold": { "value": "600", "type": "fontWeight" },
      "bold": { "value": "700", "type": "fontWeight" }
    },
    "line-height": {
      "tight": { "value": "1.25", "type": "number" },
      "normal": { "value": "1.5", "type": "number" },
      "relaxed": { "value": "1.75", "type": "number" }
    },
    "letter-spacing": {
      "tight": { "value": "-0.025em", "type": "dimension" },
      "normal": { "value": "0", "type": "dimension" },
      "wide": { "value": "0.05em", "type": "dimension" }
    },
    "font-source": {
      "heading": { "value": "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap", "type": "fontSource" },
      "body": { "value": "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap", "type": "fontSource" },
      "mono": { "value": "https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&display=swap", "type": "fontSource" }
    }
  },
  "spacing": {
    "1": { "value": "4px", "type": "dimension" },
    "2": { "value": "8px", "type": "dimension" },
    "3": { "value": "12px", "type": "dimension" },
    "4": { "value": "16px", "type": "dimension" },
    "5": { "value": "20px", "type": "dimension" },
    "6": { "value": "24px", "type": "dimension" },
    "8": { "value": "32px", "type": "dimension" },
    "10": { "value": "40px", "type": "dimension" },
    "12": { "value": "48px", "type": "dimension" },
    "16": { "value": "64px", "type": "dimension" }
  },
  "borderRadius": {
    "sm": { "value": "4px", "type": "dimension" },
    "md": { "value": "8px", "type": "dimension" },
    "lg": { "value": "12px", "type": "dimension" },
    "xl": { "value": "16px", "type": "dimension" },
    "full": { "value": "9999px", "type": "dimension" }
  },
  "shadow": {
    "sm": { "value": "0 1px 2px rgba(0,0,0,0.05)", "type": "shadow" },
    "md": { "value": "0 4px 6px -1px rgba(0,0,0,0.07)", "type": "shadow" },
    "lg": { "value": "0 10px 15px -3px rgba(0,0,0,0.1)", "type": "shadow" },
    "xl": { "value": "0 20px 25px -5px rgba(0,0,0,0.1)", "type": "shadow" }
  },
  "components": {
    "button-primary": {
      "background": "{color.primary}",
      "color": "#FFFFFF",
      "border-radius": "{borderRadius.md}",
      "padding": "{spacing.3} {spacing.6}",
      "font-weight": "{typography.font-weight.semibold}",
      "font-size": "{typography.font-size.sm}"
    },
    "button-secondary": {
      "background": "transparent",
      "color": "{color.text-primary}",
      "border": "1px solid {color.border}",
      "border-radius": "{borderRadius.md}",
      "padding": "{spacing.3} {spacing.6}",
      "font-weight": "{typography.font-weight.semibold}",
      "font-size": "{typography.font-size.sm}"
    },
    "button-ghost": {
      "background": "transparent",
      "color": "{color.primary}",
      "border-radius": "{borderRadius.md}",
      "padding": "{spacing.3} {spacing.6}",
      "font-weight": "{typography.font-weight.medium}",
      "font-size": "{typography.font-size.sm}",
      "hover-background": "{color.primary-light}"
    },
    "card": {
      "background": "{color.surface}",
      "border": "1px solid {color.border}",
      "border-radius": "{borderRadius.lg}",
      "padding": "{spacing.6}",
      "shadow": "{shadow.sm}"
    },
    "input": {
      "background": "{color.surface}",
      "border": "1px solid {color.border}",
      "border-radius": "{borderRadius.md}",
      "padding": "{spacing.3} {spacing.4}",
      "font-size": "{typography.font-size.sm}",
      "color": "{color.text-primary}",
      "placeholder-color": "{color.text-tertiary}",
      "focus-border": "{color.primary}"
    },
    "badge": {
      "border-radius": "{borderRadius.sm}",
      "padding": "{spacing.1} {spacing.2}",
      "font-size": "{typography.font-size.xs}",
      "font-weight": "{typography.font-weight.semibold}"
    },
    "nav-item": {
      "font-weight": "{typography.font-weight.medium}",
      "font-size": "{typography.font-size.sm}",
      "color": "{color.text-secondary}",
      "active-color": "{color.primary}",
      "active-background": "{color.primary-light}",
      "border-radius": "{borderRadius.md}"
    }
  }
}
```
