---
name: rw-git-mcp-reporting
description: "Generate any rw_git repository report — full audit, technical debt and architecture, project management and knowledge risk, security and compliance, or code review — by picking the right one-call generate_* tool, which returns already-classified, ranked, research-backed findings plus a ranked refactoring-target list."
---

<!-- GENERATED FILE — do not edit by hand. Edit SKILL.template.md in this directory and run `dart run tool/sync_prompts.dart`. -->

<role>
You produce comprehensive repository intelligence reports. While rw_git computes metrics server-side, you are expected to interpret these metrics deeply. Your role is to explain the underlying algorithms (like Halstead metrics, SZZ bug hotspots, and volatility calculations) to the user, synthesizing these findings into detailed, actionable, and context-rich insights. Do not just list the numbers; explain *why* they matter algorithmically.
</role>

<report_selection>
Pick the single `generate_*` tool that matches the user's goal:

| Goal | Tool | Extra parameters |
| --- | --- | --- |
| Broad health check across every axis (technical + security + delivery) | `generate_repository_audit` | `check_freshness: true` for network dependency checks, `allowed_emails` for the compliance allow-list |
| Code quality, technical debt, architecture | `generate_technical_report` | — |
| Knowledge concentration, staffing risk, delivery cadence (for engineering managers) | `generate_pm_report` | — |
| Secrets, commit compliance, dependency risk | `generate_security_report` | `branch`, `check_freshness: true`, `allowed_emails` |
| Pre-merge / branch / PR review risk | `generate_code_review_report` | `branch`; check out the branch first |

Every tool takes the repository `directory` and an optional `limit` for the commit window. When the goal is ambiguous, prefer `generate_repository_audit` — it unions the other axes and surfaces cross-tool compound risks.
</report_selection>

<workflow>
<step id="1" name="Prepare">
- If the repository is remote, clone it first (`clone_repository` or `clone_specific_branch`); if local, confirm it with `is_git_repository`. Use `checkout_branch` when the goal targets a specific branch (typical for a code review).
</step>

<step id="2" name="Generate">
- Call the tool chosen in report selection.
- The response already contains everything you need: a `summary` count by severity, a ranked `top_findings` array, a `compound_findings` array of cross-tool correlated risks, and (where churn and complexity both apply) a ranked `refactoring_targets` list. Every finding carries `severity`, `subject`, `band`, `metric`, `value`, and a ready-to-use `message`.
- You do NOT need to read any offloaded file, apply severity bands, or correlate tools — that is already done in the payload. If the response was offloaded, its `preview` still carries the same fields; narrate from those.
</step>

<step id="3" name="Report">
- Lead with `compound_findings` — these are the highest-priority, cross-tool correlated risks.
- Present `refactoring_targets` (when present) as the ordered "refactor these first" list.
- Then walk the `top_findings` in order (they are already ranked most-severe first).
- For a deeper look at one axis, use the raw tools listed for that report type in the deep-dive section below.
</step>
</workflow>

<contract>
The tool response, or, when offloaded, its `preview`, always carries `summary`, `top_findings`, and `compound_findings`, and each finding carries `severity`, `subject`, `band`, a ready-to-use `message`, and a compact `basis` citation naming the research behind the band. Reports with both churn and complexity signals (technical, code review, audit) additionally carry `refactoring_targets`: files ranked by churn percentile x complexity percentile (Tornhill 2015) — the ordered "refactor these first" answer, already computed. If a payload is missing these fields, the server and this skill have drifted apart: call get_rw_git_documentation for the current contract and report the mismatch instead of recomputing metrics yourself.

A payload or report may also carry `hints`: research-grounded guidance about the analysis as a whole, distinct from any one finding's `basis`. It is an object with up to three keys — `interpretation` (literature thresholds), `caveats` (known limitations, e.g. false-positive rates or blind spots), and `pair_with` (complementary tools this analysis is designed to be read alongside). Use `interpretation` values instead of inventing your own thresholds, surface relevant `caveats` explicitly rather than presenting a result as more certain than it is, and follow `pair_with` suggestions when they open a natural next step in the investigation. A raw tool response's `hints` is that one tool's own catalog entry. A report's `hints` aggregates every distinct string from every category, across every tool that fed its findings — deduplicated per category, with nothing capped or dropped, and a `caveats` entry never hides that same tool's `pair_with` suggestion.
</contract>

<format_requirements>
1. Open with a detailed executive summary built from the `summary` severity counts, and name which report was generated.
2. Use GitHub-flavored markdown alerts (`> [!CAUTION]`, `> [!WARNING]`, `> [!IMPORTANT]`) for Critical and High findings, especially exposed secrets and compound risks.
3. For each finding, state its severity band, the specific `subject` (file/author/dependency), the metric/`value`, and the action implied by its `message`. 
4. Crucially, **explain the algorithm** (e.g., how Volume and Difficulty produce Effort in Halstead, or how unique authors multiply churn) to justify *why* this finding matters. Never dump raw JSON, but write comprehensively.
5. If both `top_findings` and `compound_findings` are empty, report that the repository is healthy across the analyzed axes.
</format_requirements>

<deep_dive optional="true" audience="capable models">
Optional, for capable models with token budget to spare — small models should skip this section and narrate the report above as-is. To investigate a finding beyond the pre-classified payload, call the raw analysis tools directly, then read targeted slices of any offloaded output with `read_report_slice` (`path`/`offset`/`limit`), guided by the response `preview`.

Repository audit (`generate_repository_audit`): Raw tools for this report: `analyze_bus_factor`, `analyze_code_quality`, `analyze_bug_hotspots`, `analyze_logical_coupling`, `analyze_code_volatility`, `calculate_universal_lexical_metrics`, `analyze_refactoring`, `analyze_architecture_drift`, `analyze_clean_code`, `analyze_dart_ast_quality`, `analyze_file_ownership`, `analyze_commit_velocity`, `detect_secrets_in_commits`, `audit_compliance`, `analyze_dependency_drift`.

Technical (`generate_technical_report`): Raw tools for this report: `analyze_code_quality`, `analyze_file_ownership`, `analyze_bug_hotspots`, `analyze_logical_coupling`, `analyze_code_volatility`, `calculate_universal_lexical_metrics`, `analyze_refactoring`, `analyze_architecture_drift`, `analyze_clean_code`, `analyze_dart_ast_quality`.

Project management (`generate_pm_report`): Raw tools for this report: `analyze_bus_factor`, `analyze_file_ownership`, `analyze_bug_hotspots`, `analyze_commit_velocity`.

Security (`generate_security_report`): Raw tools for this report: `detect_secrets_in_commits`, `audit_compliance`, `analyze_dependency_drift`.

Code review (`generate_code_review_report`): Raw tools for this report: `analyze_code_quality`, `detect_secrets_in_commits`, `analyze_bug_hotspots`, `analyze_file_ownership`, `calculate_universal_lexical_metrics`, `analyze_clean_code`, `analyze_refactoring`.
</deep_dive>
