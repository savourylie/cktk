# Design Token JSON Schema

The canonical output format, inspired by the W3C Design Tokens Community Group spec but simplified for LLM consumption.

## Top-Level Structure

```json
{
  "meta": { ... },
  "color": { ... },
  "typography": { ... },
  "spacing": { ... },
  "borderRadius": { ... },
  "shadow": { ... },
  "components": { ... }
}
```

## Required Sections

### meta (required)

```json
{
  "meta": {
    "name": "string — descriptive name for this design system",
    "source": "string — what the tokens were extracted from",
    "version": "string — semver, default '1.0.0'",
    "generated": "string — ISO date"
  }
}
```

### color (required)

Each token: `{ "value": "<hex>", "type": "color" }`

Expected token names (include all that are identifiable):

| Token path | Purpose |
|---|---|
| `color.primary` | Primary brand / action color |
| `color.primary-light` | Lighter variant (hover, tint) |
| `color.primary-dark` | Darker variant (pressed, shade) |
| `color.secondary` | Secondary brand color |
| `color.accent` | Accent / highlight color |
| `color.background` | Page background |
| `color.surface` | Card / elevated surface background |
| `color.text-primary` | Main body text |
| `color.text-secondary` | Muted / secondary text |
| `color.text-tertiary` | Placeholder / disabled text |
| `color.border` | Default border color |
| `color.border-light` | Subtle border variant |
| `color.error` | Error state |
| `color.warning` | Warning state |
| `color.success` | Success state |
| `color.info` | Informational state |

Additional colors may be added as needed (e.g., `color.nav-bg`, `color.code-bg`).

### typography (required)

Organized into sub-groups:

```json
{
  "typography": {
    "font-family-heading": { "value": "'Font Name', fallback", "type": "fontFamily" },
    "font-family-body": { "value": "'Font Name', fallback", "type": "fontFamily" },
    "font-family-mono": { "value": "'Font Name', monospace", "type": "fontFamily" },
    "font-size": {
      "xs":   { "value": "12px", "type": "dimension" },
      "sm":   { "value": "14px", "type": "dimension" },
      "base": { "value": "16px", "type": "dimension" },
      "lg":   { "value": "18px", "type": "dimension" },
      "xl":   { "value": "20px", "type": "dimension" },
      "2xl":  { "value": "24px", "type": "dimension" },
      "3xl":  { "value": "30px", "type": "dimension" },
      "4xl":  { "value": "36px", "type": "dimension" },
      "5xl":  { "value": "48px", "type": "dimension" }
    },
    "font-weight": {
      "regular":  { "value": "400", "type": "fontWeight" },
      "medium":   { "value": "500", "type": "fontWeight" },
      "semibold": { "value": "600", "type": "fontWeight" },
      "bold":     { "value": "700", "type": "fontWeight" }
    },
    "line-height": {
      "tight":   { "value": "1.25", "type": "number" },
      "normal":  { "value": "1.5", "type": "number" },
      "relaxed": { "value": "1.75", "type": "number" }
    },
    "letter-spacing": {
      "tight":   { "value": "-0.025em", "type": "dimension" },
      "normal":  { "value": "0", "type": "dimension" },
      "wide":    { "value": "0.05em", "type": "dimension" }
    },
    "font-source": {
      "heading": { "value": "https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap", "type": "fontSource" },
      "body":    { "value": "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap", "type": "fontSource" },
      "mono":    { "value": "https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&display=swap", "type": "fontSource" }
    }
  }
}
```

Only include font-size values that are actually observed. The scale above is illustrative — use the values extracted from the screenshot.

**Font source rules:**
- Construct Google Fonts URLs from the identified font name and the extracted weight values (include `&display=swap` for performance)
- If the font is a system font (SF Pro, Helvetica Neue, Arial, Helvetica, Georgia, system-ui), set the value to `"system"` — no import is needed
- The `font-source` keys (`heading`, `body`, `mono`) correspond to the `font-family-heading`, `font-family-body`, and `font-family-mono` tokens

### spacing (required)

```json
{
  "spacing": {
    "1":  { "value": "4px",  "type": "dimension" },
    "2":  { "value": "8px",  "type": "dimension" },
    "3":  { "value": "12px", "type": "dimension" },
    "4":  { "value": "16px", "type": "dimension" },
    "6":  { "value": "24px", "type": "dimension" },
    "8":  { "value": "32px", "type": "dimension" },
    "12": { "value": "48px", "type": "dimension" },
    "16": { "value": "64px", "type": "dimension" }
  }
}
```

Infer the base unit (commonly 4px or 8px) and list the full scale observed.

### borderRadius (required)

```json
{
  "borderRadius": {
    "none": { "value": "0px",    "type": "dimension" },
    "sm":   { "value": "4px",    "type": "dimension" },
    "md":   { "value": "8px",    "type": "dimension" },
    "lg":   { "value": "12px",   "type": "dimension" },
    "xl":   { "value": "16px",   "type": "dimension" },
    "full": { "value": "9999px", "type": "dimension" }
  }
}
```

### shadow (required)

```json
{
  "shadow": {
    "sm": { "value": "0 1px 2px rgba(0,0,0,0.05)",  "type": "shadow" },
    "md": { "value": "0 4px 6px rgba(0,0,0,0.07)",  "type": "shadow" },
    "lg": { "value": "0 10px 15px rgba(0,0,0,0.1)",  "type": "shadow" }
  }
}
```

### components (optional but recommended)

Reference primitive tokens using `{token.path}` syntax:

```json
{
  "components": {
    "button-primary": {
      "background": "{color.primary}",
      "color": "#FFFFFF",
      "border-radius": "{borderRadius.md}",
      "padding": "{spacing.3} {spacing.6}",
      "font-weight": "{typography.font-weight.semibold}",
      "font-size": "{typography.font-size.sm}"
    },
    "card": {
      "background": "{color.surface}",
      "border": "1px solid {color.border}",
      "border-radius": "{borderRadius.lg}",
      "padding": "{spacing.6}",
      "shadow": "{shadow.md}"
    },
    "input": {
      "background": "{color.background}",
      "border": "1px solid {color.border}",
      "border-radius": "{borderRadius.md}",
      "padding": "{spacing.3} {spacing.4}",
      "font-size": "{typography.font-size.base}",
      "color": "{color.text-primary}",
      "placeholder-color": "{color.text-tertiary}"
    }
  }
}
```

## Token Value Rules

- **Colors**: always 6-digit hex (`#2563EB`), not 3-digit or named colors
- **Dimensions**: always `px` (consumers convert to rem/pt/dp)
- **Shadows**: CSS shadow syntax with `rgba()` for opacity
- **Font families**: quoted family name with generic fallback
- **Font weights**: numeric values (400, 500, 600, 700)
- **Line heights**: unitless ratios
- **Font sources**: valid URL string (e.g., Google Fonts URL) or the literal `"system"` for system fonts
- **Letter spacing**: `em` units
- **Component references**: `{section.token-name}` syntax
