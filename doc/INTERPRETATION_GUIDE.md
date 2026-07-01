# rw-git Interpretation Guide (Severity Bands & Compound Risks)

> **You usually do not need to apply this by hand.** The one-call report
> meta-tools (`generate_technical_report`, `generate_security_report`,
> `generate_pm_report`, `generate_code_review_report`,
> `generate_repository_audit`) apply every band and compound-risk rule below in
> deterministic Dart and return already-classified, ranked findings. Prefer
> those tools — narrate their `top_findings`/`compound_findings` directly.
>
> This document is the reference for the bands, and for power users who call the
> raw analysis tools individually and want to classify the numbers themselves.
> The bands are implemented in `lib/src/intelligence/interpretation/` (see
> `classifiers/` and `compound_finding_correlator.dart`).

Tool outputs are raw metrics with no built-in verdict — apply the bands below to
turn numbers into findings. Where an absolute industry standard exists, use it;
where a metric is repo-specific (e.g. raw keyword-count complexity), compare it
against that repo's own distribution instead of inventing an absolute cutoff.

## Bus factor / ownership concentration (`analyze_bus_factor`, `analyze_file_ownership`)
- Single author > 50% of a file/module's commits, no second contributor with a
  meaningful share → **Critical** (single point of failure).
- Top contributor 30–50% → **Moderate**.
- < 30% → Healthy distribution.

## Bug hotspots & time-to-fix (`analyze_bug_hotspots`)
- A file's `file_average_time_to_fix_in_hours` > 2x
  `global_average_time_to_fix_in_hours` → **Critical**.
- 1–2x global average → **Elevated**.
- Files in the top decile of `file_hotspots` counts → hotspot regardless of fix
  time.

## Code complexity (`analyze_code_quality`, `calculate_universal_lexical_metrics`, `analyze_dart_ast_quality`)
- `file_complexity` is a raw keyword count, not a normalized score — compare each
  file against the repo's own median: > 2x median → **High outlier**; 1–2x →
  **Elevated**; ≤ median → Normal.
- Where genuine per-function McCabe cyclomatic complexity is available (the
  language-agnostic lexical metrics engine, `calculate_universal_lexical_metrics`
  / `analyze_clean_code`), use the standard bands: 1–10 simple, 11–20 moderate,
  21–50 complex/high-risk, 51+ very high risk / effectively untestable.

## Logical coupling / co-change (`analyze_logical_coupling`)
- Two files with > 60% co-change confidence → **Strong implicit coupling**
  (candidate for merge, shared interface, or module-boundary fix).
- 30–60% → **Moderate**, worth watching.
- < 30% → Incidental.

## Architecture drift (`analyze_architecture_drift`)
- A shift of more than ~15 percentage points in a layer's share of commits over
  the analysis window, especially when responsibility crosses a boundary it
  shouldn't (e.g. business logic landing in a `ui/` directory) → **Drift
  signal**.

## Dependency freshness (`analyze_dependency_drift` with `check_freshness: true`)
- Major version behind → **Critical**: breaking-change and unpatched-CVE risk.
- Minor version behind → **Moderate**: schedule an upgrade.
- Patch version behind → **Low**: routine maintenance.

## Compliance / commit signing (`audit_compliance`)
- Unsigned commits or non-standard author domains in a repo with a stated
  signing/compliance policy → flag; severity depends on whether the repo handles
  secrets or regulated data.

## Cross-tool correlation (compound risk)
These rarely surface from any single tool and are correlated automatically by the
report meta-tools:
- Bug hotspot (top decile) **+** single-owner file on the same file →
  **Critical**: undocumented tribal knowledge in the buggiest code.
- Complexity High outlier **+** high churn on the same file → **Critical**:
  actively-changing complex code is your prime defect-injection risk.
- Strong logical coupling between files in different declared modules/layers →
  architecture smell, treat as equivalent to a drift signal.
- Dependency major-version-behind **+** a `detect_secrets_in_commits` finding in
  that dependency's config → escalate to a single **Critical** security finding.

Do not report a raw metric on its own — always state which band it falls in and,
where applicable, whether it correlates with another tool's finding.
