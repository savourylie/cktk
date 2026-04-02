# WCAG 2.2 Success Criteria Reference for React/Next.js

Quick-reference of all WCAG 2.2 success criteria organized by the four POUR principles, with common React/Next.js failure patterns for each criterion.

---

## 1. Perceivable

Information and user interface components must be presentable to users in ways they can perceive.

### Guideline 1.1 — Text Alternatives

| SC | Level | Name | Description | Common React Failures |
|----|-------|------|-------------|----------------------|
| 1.1.1 | A | Non-text Content | All non-text content has a text alternative | `<img>` / `<Image>` without `alt`; icon buttons without `aria-label`; decorative images missing `alt=""`; `<svg>` without `<title>` or `aria-label`; CSS background images conveying info without text alternative |

### Guideline 1.2 — Time-based Media

| SC | Level | Name | Description | Common React Failures |
|----|-------|------|-------------|----------------------|
| 1.2.1 | A | Audio-only and Video-only (Prerecorded) | Alternatives for prerecorded audio/video | `<video>` or `<audio>` without transcript link |
| 1.2.2 | A | Captions (Prerecorded) | Captions for prerecorded audio in synchronized media | `<video>` without `<track kind="captions">` |
| 1.2.3 | A | Audio Description or Media Alternative (Prerecorded) | Audio description or text alternative for prerecorded video | No audio description track or text transcript provided |
| 1.2.4 | AA | Captions (Live) | Captions for live audio in synchronized media | Live streams without real-time captioning integration |
| 1.2.5 | AA | Audio Description (Prerecorded) | Audio description for prerecorded video | Video content without `<track kind="descriptions">` |
| 1.2.6 | AAA | Sign Language (Prerecorded) | Sign language interpretation for prerecorded audio | N/A — typically handled outside code |
| 1.2.7 | AAA | Extended Audio Description (Prerecorded) | Extended audio description when pauses are insufficient | N/A — content-level concern |
| 1.2.8 | AAA | Media Alternative (Prerecorded) | Text alternative for prerecorded synchronized media | Missing full text transcript for video content |
| 1.2.9 | AAA | Audio-only (Live) | Alternative for live audio-only content | Live audio without real-time text alternative |

### Guideline 1.3 — Adaptable

| SC | Level | Name | Description | Common React Failures |
|----|-------|------|-------------|----------------------|
| 1.3.1 | A | Info and Relationships | Information structure conveyed programmatically | `<input>` without associated `<label>`; layout tables without `role="presentation"`; heading hierarchy skips (h1→h3); lists built with `<div>` instead of `<ul>`/`<ol>`; form groups without `<fieldset>`/`<legend>` |
| 1.3.2 | A | Meaningful Sequence | Reading order is correct programmatically | CSS `order`, `flex-direction: row-reverse`, or absolute positioning creating visual order that differs from DOM order |
| 1.3.3 | A | Sensory Characteristics | Instructions don't rely solely on shape, color, size, location, orientation, or sound | "Click the red button" or "see the sidebar on the left" without programmatic identification |
| 1.3.4 | AA | Orientation | Content not restricted to a single display orientation | CSS `@media (orientation: portrait)` hiding content; JS orientation lock without essential need |
| 1.3.5 | AA | Identify Input Purpose | Input purpose can be programmatically determined | Form inputs missing `autoComplete` attribute for personal data fields (name, email, address, etc.) |
| 1.3.6 | AAA | Identify Purpose | Purpose of UI components can be programmatically determined | Missing ARIA landmarks; no `role` attributes on custom components |

### Guideline 1.4 — Distinguishable

| SC | Level | Name | Description | Common React Failures |
|----|-------|------|-------------|----------------------|
| 1.4.1 | A | Use of Color | Color is not the sole means of conveying information | Error states only indicated by red text; required fields only marked with color; chart data only differentiated by color |
| 1.4.2 | A | Audio Control | Mechanism to pause/stop/control audio that plays >3 seconds | `<audio autoPlay>` or `<video autoPlay>` without `muted` and without visible controls |
| 1.4.3 | AA | Contrast (Minimum) | Text contrast ratio ≥4.5:1 (normal) / ≥3:1 (large) | Low-contrast placeholder text; light gray on white; styled components with insufficient contrast |
| 1.4.4 | AA | Resize Text | Text can be resized up to 200% without loss of content | Fixed `px` font sizes; containers with `overflow: hidden` that clip on zoom; viewport-unit-only typography |
| 1.4.5 | AA | Images of Text | Text is used instead of images of text | Logos rendered as images with text; hero sections using images of text instead of styled HTML |
| 1.4.6 | AAA | Contrast (Enhanced) | Text contrast ratio ≥7:1 (normal) / ≥4.5:1 (large) | Same as 1.4.3 but stricter |
| 1.4.7 | AAA | Low or No Background Audio | Speech audio has minimal background noise | N/A — content-level concern |
| 1.4.8 | AAA | Visual Presentation | Text block presentation customizable | Fixed line-height; no mechanism to change foreground/background colors; line width >80 characters |
| 1.4.9 | AAA | Images of Text (No Exception) | Images of text only used for decoration or essential | Same as 1.4.5 but no exceptions |
| 1.4.10 | AA | Reflow | Content reflows at 320px width without horizontal scroll | Horizontal scrollbars at 320px viewport; `min-width` values preventing reflow; fixed-width layouts |
| 1.4.11 | AA | Non-text Contrast | UI components and graphics have ≥3:1 contrast | Custom checkboxes, radio buttons, toggle switches, or icons with low contrast against background |
| 1.4.12 | AA | Text Spacing | Content adapts to user text spacing overrides | Content clips or overlaps when line-height set to 1.5x, letter-spacing to 0.12em, word-spacing to 0.16em, paragraph spacing to 2x |
| 1.4.13 | AA | Content on Hover or Focus | Hover/focus-triggered content is dismissible, hoverable, persistent | Tooltips that disappear when moving mouse to them; popovers not dismissible with Escape; content that auto-hides |

---

## 2. Operable

User interface components and navigation must be operable.

### Guideline 2.1 — Keyboard Accessible

| SC | Level | Name | Description | Common React Failures |
|----|-------|------|-------------|----------------------|
| 2.1.1 | A | Keyboard | All functionality available from keyboard | `onClick` on `<div>`/`<span>` without `onKeyDown`/`onKeyUp`; custom dropdowns not keyboard navigable; drag-and-drop without keyboard alternative |
| 2.1.2 | A | No Keyboard Trap | Keyboard focus can be moved away from any component | Modal dialogs without proper focus management; custom widgets that capture Tab key; infinite focus loops |
| 2.1.3 | AAA | Keyboard (No Exception) | All functionality available from keyboard, no exceptions | Same as 2.1.1 but stricter |
| 2.1.4 | A | Character Key Shortcuts | Single-character keyboard shortcuts can be remapped or disabled | Custom keyboard shortcuts using single letters without modifier keys; no mechanism to remap |

### Guideline 2.2 — Enough Time

| SC | Level | Name | Description | Common React Failures |
|----|-------|------|-------------|----------------------|
| 2.2.1 | A | Timing Adjustable | Time limits can be adjusted | `setTimeout` redirects without warning; session timeouts without extend option; timed form submissions |
| 2.2.2 | A | Pause, Stop, Hide | Moving/blinking/scrolling/auto-updating content can be paused | Auto-scrolling carousels without pause; animated banners; live data feeds without pause control |
| 2.2.3 | AAA | No Timing | No time limits except for real-time events | Any non-essential timeout |
| 2.2.4 | AAA | Interruptions | Interruptions can be postponed or suppressed | Push notifications or toasts that cannot be suppressed |
| 2.2.5 | AAA | Re-authenticating | Data preserved on re-authentication | Form data lost when session expires |
| 2.2.6 | AAA | Timeouts | Users warned of data loss from inactivity | No warning before session timeout causes data loss |

### Guideline 2.3 — Seizures and Physical Reactions

| SC | Level | Name | Description | Common React Failures |
|----|-------|------|-------------|----------------------|
| 2.3.1 | A | Three Flashes or Below Threshold | No content flashes more than 3 times per second | CSS animations or video content with rapid flashing; uncontrolled GIF animations |
| 2.3.2 | AAA | Three Flashes | No content flashes more than 3 times per second (absolute) | Same as 2.3.1 but stricter |
| 2.3.3 | AAA | Animation from Interactions | Motion animation can be disabled | Animations without `prefers-reduced-motion` media query support |

### Guideline 2.4 — Navigable

| SC | Level | Name | Description | Common React Failures |
|----|-------|------|-------------|----------------------|
| 2.4.1 | A | Bypass Blocks | Mechanism to bypass repeated content | No skip-to-content link; no landmark regions (`<main>`, `<nav>`, `<aside>`) |
| 2.4.2 | A | Page Titled | Pages have descriptive titles | Missing or generic `<title>`; Next.js pages without `<Head><title>` or metadata; SPA not updating document.title on navigation |
| 2.4.3 | A | Focus Order | Focus order preserves meaning and operability | `tabIndex` > 0; DOM order mismatching visual order; modals not trapping focus; dynamically inserted content not receiving focus |
| 2.4.4 | A | Link Purpose (In Context) | Link purpose determinable from link text or context | "Click here", "Read more", "Learn more" without context; icon-only links without `aria-label` |
| 2.4.5 | AA | Multiple Ways | More than one way to locate a page | No search, sitemap, or alternative navigation |
| 2.4.6 | AA | Headings and Labels | Headings and labels are descriptive | Generic headings like "Section 1"; form labels that don't describe the input |
| 2.4.7 | AA | Focus Visible | Keyboard focus indicator is visible | `outline: none` or `outline: 0` without replacement focus style; `:focus { outline: none }` in global CSS |
| 2.4.8 | AAA | Location | User's location within a site is indicated | No breadcrumbs; no current-page indicator in navigation |
| 2.4.9 | AAA | Link Purpose (Link Only) | Link purpose determinable from link text alone | Same as 2.4.4 but stricter |
| 2.4.10 | AAA | Section Headings | Section headings organize content | Content sections without heading structure |
| 2.4.11 | AA | Focus Not Obscured (Minimum) | Focused element is not entirely hidden | Sticky headers/footers covering focused elements; off-screen elements receiving focus |
| 2.4.12 | AAA | Focus Not Obscured (Enhanced) | Focused element is fully visible | Same as 2.4.11 but no partial obscuring allowed |
| 2.4.13 | AA | Focus Appearance | Focus indicator meets minimum area and contrast | Thin dotted outlines; low-contrast focus rings; focus indicators smaller than required area |

### Guideline 2.5 — Input Modalities

| SC | Level | Name | Description | Common React Failures |
|----|-------|------|-------------|----------------------|
| 2.5.1 | A | Pointer Gestures | Multi-point/path gestures have single-pointer alternative | Pinch-to-zoom or swipe without button alternatives; custom gesture-only interactions |
| 2.5.2 | A | Pointer Cancellation | Down-event doesn't trigger function; can abort/undo | `onMouseDown` or `onTouchStart` triggering destructive actions without undo |
| 2.5.3 | A | Label in Name | Visible label matches accessible name | `aria-label` not containing visible button text; `aria-labelledby` referencing different text |
| 2.5.4 | A | Motion Actuation | Motion-triggered functionality has UI alternative and can be disabled | Shake-to-undo without button alternative; tilt-to-scroll without standard scrolling |
| 2.5.5 | AAA | Target Size (Enhanced) | Target size at least 44x44 CSS pixels | Tiny clickable icons; small close buttons; dense link lists |
| 2.5.6 | AAA | Concurrent Input Mechanisms | Input modalities not restricted | Disabling mouse input in touch mode or vice versa |
| 2.5.7 | AA | Dragging Movements | Dragging has single-pointer alternative | Drag-and-drop without arrow-key or button alternatives; sortable lists requiring drag |
| 2.5.8 | AA | Target Size (Minimum) | Target size at least 24x24 CSS pixels or has sufficient spacing | Small interactive elements (icons, close buttons) below 24x24; inline links in dense text |

---

## 3. Understandable

Information and the operation of user interface must be understandable.

### Guideline 3.1 — Readable

| SC | Level | Name | Description | Common React Failures |
|----|-------|------|-------------|----------------------|
| 3.1.1 | A | Language of Page | Default language specified in HTML | `<html>` without `lang` attribute; Next.js `_document.tsx` missing `lang` on `<Html>` |
| 3.1.2 | AA | Language of Parts | Language of passages/phrases identified | Foreign-language content without `lang` attribute on containing element |
| 3.1.3 | AAA | Unusual Words | Mechanism for definitions of jargon/idioms | Technical terms without glossary or definitions |
| 3.1.4 | AAA | Abbreviations | Mechanism for expanded form of abbreviations | Abbreviations without `<abbr>` tag or first-use expansion |
| 3.1.5 | AAA | Reading Level | Content available at lower secondary education level | Overly complex language without simplified version |
| 3.1.6 | AAA | Pronunciation | Mechanism for pronunciation of ambiguous words | N/A — rare in web apps |

### Guideline 3.2 — Predictable

| SC | Level | Name | Description | Common React Failures |
|----|-------|------|-------------|----------------------|
| 3.2.1 | A | On Focus | No context change on focus | `onFocus` triggering navigation, form submission, or modal opening |
| 3.2.2 | A | On Input | No context change on input without warning | `onChange` on `<select>` triggering navigation; auto-submitting forms on input |
| 3.2.3 | AA | Consistent Navigation | Navigation mechanisms consistent across pages | Dynamic nav ordering; pages with different navigation patterns |
| 3.2.4 | AA | Consistent Identification | Components with same functionality identified consistently | Same action using different labels across pages ("Submit" vs "Send" vs "Go") |
| 3.2.5 | AAA | Change on Request | Context changes only on user request | Auto-redirects; content that changes without user action |
| 3.2.6 | AA | Consistent Help | Help mechanisms in consistent location | Help links/chat widgets in different positions across pages |

### Guideline 3.3 — Input Assistance

| SC | Level | Name | Description | Common React Failures |
|----|-------|------|-------------|----------------------|
| 3.3.1 | A | Error Identification | Input errors detected and described in text | Error messages only using color; validation errors not associated with inputs via `aria-describedby`; generic "form has errors" without specifics |
| 3.3.2 | A | Labels or Instructions | Labels or instructions for user input | Placeholder-only inputs (no visible label); missing instructions for complex inputs (date format, password requirements) |
| 3.3.3 | AA | Error Suggestion | Error messages include correction suggestions | "Invalid input" without explaining what's expected |
| 3.3.4 | AA | Error Prevention (Legal, Financial, Data) | Submissions are reversible, verified, or confirmed | Destructive actions without confirmation; no review step for financial transactions |
| 3.3.5 | AAA | Help | Context-sensitive help available | Complex forms without help text or instructions |
| 3.3.6 | AAA | Error Prevention (All) | Submissions are reversible, verified, or confirmed for all forms | Same as 3.3.4 but for all forms |
| 3.3.7 | A | Redundant Entry | Information previously entered is auto-populated or selectable | Requiring re-entry of data available from previous steps in multi-step forms |
| 3.3.8 | AA | Accessible Authentication (Minimum) | No cognitive function test for authentication | CAPTCHA without alternative; authentication requiring memorization without allowing paste |
| 3.3.9 | AAA | Accessible Authentication (Enhanced) | No cognitive function test for authentication, no exceptions | Same as 3.3.8 but stricter |

---

## 4. Robust

Content must be robust enough to be interpreted by a wide variety of user agents, including assistive technologies.

### Guideline 4.1 — Compatible

| SC | Level | Name | Description | Common React Failures |
|----|-------|------|-------------|----------------------|
| 4.1.2 | A | Name, Role, Value | All UI components have accessible name, role, and value | `<div onClick>` without `role` and `aria-label`; custom widgets without ARIA roles; toggle buttons without `aria-pressed`; custom checkboxes without `aria-checked`; expandable sections without `aria-expanded` |
| 4.1.3 | AA | Status Messages | Status messages programmatically determinable without focus | Toast notifications without `role="status"` or `role="alert"`; success/error messages without `aria-live` region; loading states without `aria-busy` |

> **Note**: SC 4.1.1 (Parsing) was removed in WCAG 2.2 as it is now handled by HTML spec requirements.

---

## Criteria Counts by Level

| Level | Count |
|-------|-------|
| A | 32 |
| AA | 24 |
| AAA | 30 |
| **Total** | **86** |

## Statically Checkable Criteria (via scan_codebase.sh)

These criteria have patterns detectable through static code analysis:

| SC | Check |
|----|-------|
| 1.1.1 | `<img>` / `<Image>` without `alt` attribute |
| 1.3.1 | `<input>` without label; `<label>` without `htmlFor`; heading hierarchy |
| 1.4.2 | `<video>` / `<audio>` with `autoPlay` without `muted` |
| 2.1.1 | `onClick` on non-interactive elements without keyboard handler |
| 2.4.3 | `tabIndex` > 0 |
| 2.4.4 | Non-descriptive link text ("click here", "read more") |
| 3.1.1 | `<html>` / `<Html>` without `lang` attribute |
| 4.1.2 | `<div>` / `<span>` with `onClick` but no `role` / `tabIndex` |
