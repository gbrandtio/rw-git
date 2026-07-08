# rw-git Interpretation Guide (Severity Bands & Compound Risks)

> **You usually do not need to apply this by hand.** The one-call report
> meta-tools (`generate_technical_report`, `generate_security_report`,
> `generate_pm_report`, `generate_code_review_report`,
> `generate_repository_audit`) apply every band and compound-risk rule below in
> deterministic Dart and return already-classified, ranked findings. Prefer
> those tools and narrate their `top_findings`/`compound_findings` directly.
>
> This document is the reference for the bands, and for power users who call the
> raw analysis tools individually and want to classify the numbers themselves.
> The bands are implemented in `lib/src/intelligence/interpretation/` (see
> `classifiers/` and `compound_finding_correlator.dart`).

Every classified finding carries its academic grounding in the payload: a
compact `basis` citation tag and a fuller `rationale` sentence with the
citation, both present inline in the offload preview. The strings are
classifier-owned constants (`researchBasis` / `researchRationale` in
`lib/src/intelligence/interpretation/classifiers/`), and the citations
resolve in [`doc/tools/REFERENCES.md`](tools/REFERENCES.md).

Tool outputs are raw metrics with no built-in verdict. You can apply the bands below to turn numbers into findings. Where an absolute industry standard exists, use it; where a metric is repo-specific (e.g. raw keyword-count complexity), compare it against that repo's own distribution instead of inventing an absolute cutoff.

## Bus factor / ownership concentration (`analyze_bus_factor`, `analyze_file_ownership`)
- Single author > 50% of a file/module's commits, no second contributor with a
  meaningful share → **Critical** (single point of failure).
- Top contributor 30–50% → **Moderate**.
- < 30% → Healthy distribution.
- **Bird minor-contributor rule**: three or more contributors each holding
  less than 5% of a file's changes → **Elevated**, independently of who the
  majority owner is. Bird et al. (FSE 2011) found minor-contributor count a
  stronger defect predictor than ownership concentration itself.

## Bug hotspots & bug lifetime (`analyze_bug_hotspots`)
- A file's `file_average_bug_lifetime_in_days` > 2x
  `global_average_bug_lifetime_in_days` → **Critical**.
- 1–2x global average → **Elevated**.
- Files in the top decile of `file_hotspots` counts → hotspot regardless of bug
  lifetime.
- **Semantics**: SZZ measures the span from the bug-*introducing* commit to the
  bug-*fixing* commit. This is the bug's lifetime and not to be confused with the effort spent fixing it once noticed. Median lifetimes of one to several hundred days are normal (Kim & Whitehead, *How long did it take to fix bugs?*, MSR 2006), which is why the metric is reported in days and the bands are relative to the repository's own average rather than absolute cutoffs.

## Code complexity (`analyze_code_quality`, `calculate_universal_lexical_metrics`, `analyze_dart_ast_quality`)
- `file_complexity` is a raw keyword count, not a normalized score — compare each file against the repo's own median: > 2x median → **High outlier**; 1–2x →
  **Elevated**; ≤ median → Normal.
- Complexity interpretation is scoped to source-code files
  (`SourceFileFilter`): the keyword proxy matches English prose ("if",
  "for", "while"), so prose/config/lockfile paths are excluded from
  complexity findings, the repo median, and the bounded lexical sample
  (hotspot analysis is defined over source files based on Tornhill et al. 2015). The scope is a denylist of definitely-not-code files; unknown extensions pass, so unprofiled languages are never dropped. The raw
  `analyze_code_quality` output remains unfiltered. When reading it
  directly, apply the same scope before comparing files to the median.
- Genuine McCabe cyclomatic complexity uses the standard absolute bands:
  1–10 simple, 11–20 moderate (**Elevated**), 21–50 complex/high-risk
  (**High**), 51+ effectively untestable (**Critical**). The technical,
  code-review, and audit reports compute this automatically for the top-churn
  files (`lexicalComplexity` findings via the `BoundedLexicalMetricsSampler`,
  ADR-0014); `calculate_universal_lexical_metrics` remains the per-file
  deep-dive path.
- Maintainability index (Coleman et al. 1994): < 65 → **High** (low / needs
  refactoring); 65–85 → **Elevated** (moderate); ≥ 85 → Healthy.
- ABC score (Fitzpatrick 1997): > 30 → **High** (needs refactoring); > 15 →
  **Elevated** (warrants review).
- NPath acyclic-path count (Nejmeh, CACM 1988): > 1000 → **High**
  (combinatorial path explosion); > 200 → **Elevated** (path coverage
  impractical).
- Cognitive complexity (Campbell 2018): > 25 → **High** (resists
  comprehension); > 15 → **Elevated** (hard to understand).
- Halstead delivered-bugs estimate (Halstead 1977, volume / 3000): > 2.0
  estimated latent bugs per file → **Elevated**.
- The bounded sampler computes the whole suite per top-churn file; one
  `lexicalComplexity` finding per file carries the worst-banding metric,
  with the full suite in `evidence`.
- Any circular import chain among the sampled Dart files (Tarjan SCC,
  Tarjan 1972; Lakhotia 1993) → **High** `dartAst` finding. Dart repos only
  (gated on `pubspec.yaml`); `analyze_dart_ast_quality` remains the
  branch-diff deep-dive path for API-signature breaks.

## Clean code heuristics (`analyze_clean_code`)
Computed automatically on the same bounded top-churn sample in the
technical, code-review, and audit reports:
- Any crossed heuristic, that is, file > 300 lines, nesting depth ≥ 5, > 10% long lines, > 10 magic-number literals, or > 10% duplicate lines (Type-1
  clones) → **Elevated** (Martin 2008; Fowler 1999; Koschke 2007).
- Three or more heuristics agreeing on one file → **High**: converging
  independent signals are a stronger maintainability predictor than any
  single one.

## Delivery cadence (`analyze_commit_velocity`)
Classified into the PM report automatically:
- Declining trend with a negative velocity slope → **Elevated**.
- Gini author-concentration coefficient > 0.6 → **High** (delivery depends on
  very few people; Gini 1912).
- More than 15% of commits in the burnout window (nights/weekends) → **High**
  (Claes, Mens & Grosjean, ICSE 2018).

## Refactoring context (`analyze_refactoring`)
Applied automatically in the technical report and audit:
- Churn/volatility findings on files renamed by detected refactorings are
  downgraded one band (churn explained by clean-up carries lower defect risk based on the RA-SZZ insight, Neto et al., SANER 2018).
- Five or more detected refactoring commits → **Elevated** repo-level
  tech-debt-paydown signal.

## Commit hygiene (`analyze_code_quality` mega/suspicious commits)
Aggregated into the repository audit, one finding per family:
- Any mega commits (> 500 lines or > 20 files) → **Moderate** aggregate.
- Any suspicious-message commits → **Moderate** aggregate.

## Logical coupling / co-change (`analyze_logical_coupling`)
- Two files with > 60% co-change confidence → **Strong implicit coupling**
  (candidate for merge, shared interface, or module-boundary fix).
- 30–60% → **Moderate**, worth watching.
- < 30% → Incidental.

## Architecture drift (`analyze_architecture_drift`)
Computed automatically in the technical report and audit over layers
inferred from the churned file paths (raw-tool callers supply their own
`layer_patterns`):
- God Component (one layer in > 50% of drift commits) and Hub-Like
  Dependency (a layer coupled with ≥ half of the other layers, 4+ layers
  declared) → **High** (Garcia, Oliveira & Murta 2009).
- Scattered Functionality (commits touching 3+ layers at once) →
  **Moderate**.
- `coupling_ratio` (share of commits crossing layer boundaries) > 15% →
  **Elevated** (Perry & Wolf 1992).
- `coupling_density` (fraction of layer pairs that co-change at all) > 50%
  → **Elevated**: the architecture behaves as an entangled whole.
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
These rarely surface from any single tool and are correlated automatically by the report meta-tools:
- Bug hotspot (top decile) **+** single-owner file on the same file →
  **Critical**: undocumented tribal knowledge in the buggiest code.
- Complexity High outlier **+** high churn on the same file → **Critical**:
  actively-changing complex code is your prime defect-injection risk.
- Strong logical coupling between files in different declared modules/layers →
  architecture smell, treat as equivalent to a drift signal.
- Genuine McCabe complexity High-or-worse **+** top-decile churn on the same
  file → **Critical**: the strongest defect-injection predictor the reports
  compute (McCabe 1976; Nagappan & Ball 2005).
- Dependency major-version-behind **+** a `detect_secrets_in_commits` finding in that dependency's config → escalate to a single **Critical** security finding.
- One author solely owning **two or more** single-owner bug-hotspot files →
  **Critical** author-level knowledge-loss risk: their departure orphans the
  buggiest code (Avelino et al. 2016; Fritz et al. 2010; Mockus & Herbsleb
  2002).
- Three or more minor contributors **+** bug hotspot on the same file →
  **High**: Bird's strongest ownership-structure defect signal on a file SZZ
  already marks defect-prone (Bird et al. 2011; Śliwerski 2005).
- Burnout-window share High **+** any active bug hotspot → **High**
  repo-level co-occurrence: off-hours commits are measurably buggier
  (Claes, Mens & Grosjean 2018; Eyolfson, Tan & Lam 2011). Deliberately a
  co-occurrence, not a per-commit causal attribution .  SZZ dates are
  UTC-normalized while the burnout window is author wall-clock.

## Refactoring targets (Tornhill hotspot prioritization)
The technical, code-review, and audit reports additionally return a ranked
`refactoring_targets` list: per-file churn percentile × complexity
percentile (genuine McCabe where sampled, else the repo-relative proxy,
each percentiled within its own population), minimum product 0.25, top 5
(Tornhill 2015; Ostrand, Weyuker & Bell 2004). Only source-code files are
ranked. Non-code paths (prose, config, lockfiles; `SourceFileFilter`)
are removed from every percentile population first, since hotspot
prioritization is defined over code and prose diffs match the keyword
proxy. This is the ordered "refactor these first" answer. Narrate it as
such rather than re-deriving priorities from individual findings.

Do not report a raw metric on its own. Always state which band it falls in and, where applicable, whether it correlates with another tool's finding.
