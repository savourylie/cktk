# WCAG Conformance Report Template

Use this template to generate the final audit report. Replace all `{{placeholder}}` values.

---

# WCAG 2.2 Accessibility Conformance Report

**Project:** {{project_name}}
**Date:** {{date}}
**Target Level:** {{target_level}} (A / AA / AAA)
**Auditor:** Claude (automated + manual review)

---

## Executive Summary

**Overall Conformance:** {{conformance_status}} (Does Not Conform / Partially Conforms / Fully Conforms at Level {{target_level}})

### Issue Counts

| Severity | Count |
|----------|-------|
| Critical (must fix — Level A violations) | {{critical_count}} |
| Serious (should fix — Level AA violations) | {{serious_count}} |
| Moderate (consider fixing — Level AAA / best practices) | {{moderate_count}} |
| **Total** | **{{total_count}}** |

### By Principle

| Principle | Issues |
|-----------|--------|
| 1. Perceivable | {{perceivable_count}} |
| 2. Operable | {{operable_count}} |
| 3. Understandable | {{understandable_count}} |
| 4. Robust | {{robust_count}} |

### By Level

| Level | Issues |
|-------|--------|
| A | {{level_a_count}} |
| AA | {{level_aa_count}} |
| AAA | {{level_aaa_count}} |

---

## Scope

### Pages / Routes Audited

| # | Route | Description |
|---|-------|-------------|
| 1 | {{route}} | {{description}} |

### Exclusions

{{exclusions_or_none}}

### Tools Used

- **Static analysis**: `scan_codebase.sh` — grep-based JSX/TSX checks
- **Automated testing**: `run_axe.js` — axe-core via Playwright ({{if_axe_was_run}})
- **Manual review**: Claude code analysis

---

## Findings

Findings are organized by WCAG principle, then by success criterion. Each finding includes the affected file/URL, code snippet, impact assessment, and recommended fix.

### 1. Perceivable

#### SC 1.1.1 — Non-text Content (Level A)

<!-- Repeat this block for each finding under this criterion -->

**Finding P-{{id}}**: {{summary}}

- **Location**: `{{file_path}}:{{line_number}}` {{or_url}}
- **Impact**: {{Critical / Serious / Moderate}} — {{impact_description}}
- **Source**: {{Static analysis / axe-core / Manual review}}

**Code**:
```tsx
{{code_snippet}}
```

**Recommendation**:
```tsx
{{fixed_code_snippet}}
```

{{explanation_if_needed}}

---

<!-- Continue for each criterion with findings... -->

#### SC 1.3.1 — Info and Relationships (Level A)

<!-- findings... -->

#### SC 1.4.3 — Contrast (Minimum) (Level AA)

<!-- findings... -->

---

### 2. Operable

#### SC 2.1.1 — Keyboard (Level A)

<!-- findings... -->

#### SC 2.4.3 — Focus Order (Level A)

<!-- findings... -->

#### SC 2.4.4 — Link Purpose (Level A)

<!-- findings... -->

#### SC 2.4.7 — Focus Visible (Level AA)

<!-- findings... -->

---

### 3. Understandable

#### SC 3.1.1 — Language of Page (Level A)

<!-- findings... -->

#### SC 3.3.1 — Error Identification (Level A)

<!-- findings... -->

---

### 4. Robust

#### SC 4.1.2 — Name, Role, Value (Level A)

<!-- findings... -->

#### SC 4.1.3 — Status Messages (Level AA)

<!-- findings... -->

---

## Criteria With No Issues Found

The following criteria were evaluated and no issues were identified:

| SC | Name | Level | Method |
|----|------|-------|--------|
| {{sc_number}} | {{sc_name}} | {{level}} | {{static / axe-core / manual}} |

---

## Prioritized Recommendations

### Critical (Fix Immediately)

Issues that prevent users with disabilities from accessing core functionality.

1. **{{recommendation}}** — Affects SC {{sc_numbers}}. {{detail}}.

### Serious (Fix Soon)

Issues that significantly impair the experience for some users.

1. **{{recommendation}}** — Affects SC {{sc_numbers}}. {{detail}}.

### Moderate (Plan to Fix)

Issues that cause inconvenience but have workarounds.

1. **{{recommendation}}** — Affects SC {{sc_numbers}}. {{detail}}.

---

## Appendix

### A. Tools and Versions

| Tool | Version |
|------|---------|
| scan_codebase.sh | 1.0 |
| axe-core | {{axe_version_or_na}} |
| Playwright | {{playwright_version_or_na}} |

### B. Testing Notes

- **Static analysis coverage**: All `*.tsx` and `*.jsx` files in the project (excluding `node_modules/`, `.next/`, `dist/`, `build/`)
- **Automated testing coverage**: {{urls_tested_or_not_performed}}
- **Manual review focus areas**: {{areas_reviewed}}

### C. Conformance Level Definitions

| Level | Meaning |
|-------|---------|
| A | Minimum level — essential accessibility. Must be met. |
| AA | Recommended level — addresses major barriers. Most regulations require this. |
| AAA | Highest level — best possible accessibility. Aspirational for most sites. |

### D. Severity Definitions

| Severity | Definition |
|----------|------------|
| Critical | Blocks access to content or functionality for users with disabilities |
| Serious | Causes significant difficulty but workaround may exist |
| Moderate | Causes some difficulty; impacts user experience but not access |
