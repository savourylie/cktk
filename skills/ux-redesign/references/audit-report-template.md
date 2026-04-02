# Audit Report Template

Use this template for `docs/reports/UX_DESIGN_REPORT.md`. Replace all `{{placeholders}}` with actual findings.

---

```markdown
# UX Design Audit Report

**Project:** {{project_name}}
**Date:** {{date}}
**Sources:** docs/PRD.md, docs/FEATURES.md, docs/UX_DESIGN.md, codebase
**Framework:** {{framework_detected}}

---

## Executive Summary

**Spec-to-Implementation Alignment:** {{Low | Moderate | High | Full}}

{{2-3 paragraph summary: what was expected, what was built, key divergences, overall assessment}}

### Finding Counts

| Severity | Count |
|----------|-------|
| Critical (UX-breaking) | {{n}} |
| Major (significant gaps) | {{n}} |
| Minor (small discrepancies) | {{n}} |
| Positive (implementation improvements) | {{n}} |
| **Total** | **{{n}}** |

---

## Implementation Inventory

### Route Map

| # | Route | File | Type | In Spec? | Notes |
|---|-------|------|------|----------|-------|
| {{n}} | {{/path}} | {{file}} | {{Page/Layout}} | {{Yes/No/Partial}} | {{notes}} |

### Navigation Structure (Implemented)

[ASCII sitemap of what was actually built]

### Component Inventory

| Component | File | Used By | Purpose | In Spec? |
|-----------|------|---------|---------|----------|
| {{name}} | {{file}} | {{screens}} | {{purpose}} | {{Yes/No}} |

---

## Gap Analysis by UX Dimension

### 1. User Intent & Mental Model

**Spec intent:** {{summary from UX_DESIGN.md section 1}}
**Implementation reality:** {{what the code actually communicates}}

| ID | Finding | Severity | Spec Says | Code Does | Impact |
|----|---------|----------|-----------|-----------|--------|
| MM-{{n}} | {{description}} | {{Critical/Major/Minor}} | {{spec}} | {{code}} | {{user impact}} |

### 2. Information Architecture

**Spec intent:** {{summary from UX_DESIGN.md section 2}}
**Implementation reality:** {{actual route/component organization}}

| ID | Finding | Severity | Spec Says | Code Does | Impact |
|----|---------|----------|-----------|-----------|--------|
| IA-{{n}} | {{description}} | {{Critical/Major/Minor}} | {{spec}} | {{code}} | {{user impact}} |

### 3. Affordances & Action Clarity

**Spec intent:** {{summary from UX_DESIGN.md section 3}}
**Implementation reality:** {{actual interactive elements}}

| ID | Finding | Severity | Spec Says | Code Does | Impact |
|----|---------|----------|-----------|-----------|--------|
| AF-{{n}} | {{description}} | {{Critical/Major/Minor}} | {{spec}} | {{code}} | {{user impact}} |

### 4. Cognitive Load & Decision Minimization

**Spec intent:** {{summary from UX_DESIGN.md section 4}}
**Implementation reality:** {{actual decision points and friction}}

| ID | Finding | Severity | Spec Says | Code Does | Impact |
|----|---------|----------|-----------|-----------|--------|
| CL-{{n}} | {{description}} | {{Critical/Major/Minor}} | {{spec}} | {{code}} | {{user impact}} |

### 5. State Design & Feedback

**Spec intent:** {{summary from UX_DESIGN.md section 5}}
**Implementation reality:** {{actual state handling}}

| ID | Finding | Severity | Spec Says | Code Does | Impact |
|----|---------|----------|-----------|-----------|--------|
| SD-{{n}} | {{description}} | {{Critical/Major/Minor}} | {{spec}} | {{code}} | {{user impact}} |

### 6. Flow Integrity

**Spec intent:** {{summary from UX_DESIGN.md section 6}}
**Implementation reality:** {{actual user flows}}

| ID | Finding | Severity | Spec Says | Code Does | Impact |
|----|---------|----------|-----------|-----------|--------|
| FI-{{n}} | {{description}} | {{Critical/Major/Minor}} | {{spec}} | {{code}} | {{user impact}} |

---

## Positive Divergences

Implementation improvements over spec that should be preserved:

| # | What | Where | Why It's Better |
|---|------|-------|-----------------|
| {{n}} | {{description}} | {{file/route}} | {{rationale}} |

---

## PRD & Feature Compliance

| Feature | Category | In Spec? | In Code? | Gap |
|---------|----------|----------|----------|-----|
| {{feature}} | {{category}} | {{Yes/No}} | {{Yes/No/Partial}} | {{description or "None"}} |

---

## Prioritized Recommendations

### Critical -- Must Address in Redesign

1. **[{{ID}}] {{title}}**
   - Finding: {{description}}
   - Recommendation: {{what to change}}

### Major -- Should Address in Redesign

1. **[{{ID}}] {{title}}**
   - Finding: {{description}}
   - Recommendation: {{what to change}}

### Minor -- Consider in Redesign

1. **[{{ID}}] {{title}}**
   - Finding: {{description}}
   - Recommendation: {{what to change}}

### Preserve -- Keep As-Is

1. **{{description}}**
   - Rationale: {{why this works well}}
```

---

## Severity Classification Guide

| Severity | Definition | Examples |
|----------|-----------|---------|
| **Critical** | UX-breaking: users cannot complete a core flow, or the implementation actively misleads | Missing navigation to key feature, contradictory affordances, no error states on critical forms |
| **Major** | Significant gap: users can work around it but with confusion or friction | IA structure differs from spec, missing loading states, inconsistent navigation patterns |
| **Minor** | Small discrepancy: noticeable but low impact | Slight ordering difference, missing progressive disclosure on non-critical feature, cosmetic state handling |
| **Positive** | Implementation improvement: code does something better than spec intended | Better progressive disclosure than specified, more intuitive navigation, additional helpful states |

## Finding ID Prefixes

| Prefix | UX Dimension |
|--------|-------------|
| MM- | User Intent & Mental Model |
| IA- | Information Architecture |
| AF- | Affordances & Action Clarity |
| CL- | Cognitive Load & Decision Minimization |
| SD- | State Design & Feedback |
| FI- | Flow Integrity |
