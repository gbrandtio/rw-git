# 0005 — Server-side interpretation layer and one-call report meta-tools

- **Status**: Accepted
- **Date**: 2026-07-01
- **Deciders**: rw_git maintainers
- **Related**: [ADR-0001](0001-file-offloading-of-large-tool-outputs.md),
  [ADR-0006](0006-targeted-retrieval-of-offloaded-reports.md)

## Context

The raw analysis tools each return metrics for one dimension (bus factor, churn,
hotspots, coupling, volatility, dependency freshness, compliance, secrets, …).
Turning those into a usable report previously required the model to:

1. orchestrate ~10 separate tool calls,
2. read each offloaded file (ADR-0001),
3. apply a ~900-word interpretation guide to classify raw numbers into severity
   bands, and
4. correlate findings across tools and rank them.

Small and local models — the explicit target of the *Small and local models
Competitive Advantage* rule — cannot reliably perform steps 2–4. The
interpretation guide was long, the correlation rules were subtle, and the whole
flow cost many hops and hundreds of thousands of worst-case read-tokens.

`AGENTS.md` also requires that *all intelligence and metrics be gathered in
runtime* and that *quality be backed by academic research* — the classification
thresholds and correlation rules are deterministic domain knowledge, not
something each model should re-derive by prompt.

## Decision

Move interpretation, correlation, and ranking **out of the LLM and into
deterministic Dart**, exposed as one-call **report meta-tools**.

- A new interpretation layer under `lib/src/intelligence/interpretation/`
  defines a `Severity`/`Finding` model, per-metric **classifiers** that map each
  analysis DTO into severity-banded findings, and a `CompoundFindingCorrelator`
  that encodes cross-tool AND-rules (a risk that only matters when two signals
  co-occur).
- A `ReportOrchestrator` runs the relevant analysis algorithms server-side,
  classifies their DTOs, correlates compound findings, and returns a bounded
  `ReportPayload` (`summary`, `top_findings`, `compound_findings`).
- Five report meta-tools expose this per audience: `generate_repository_audit`,
  `generate_technical_report`, `generate_security_report`, `generate_pm_report`,
  `generate_code_review_report`. They are registered **first** in
  `server_registry.dart` so they are the prominent choice, share the compact
  `_reportOutputSchema` (ADR-0002), and are file-offloaded (ADR-0001).
- The classifiers **reuse the existing analysis algorithms** (library-first) —
  they add an interpretation layer on top, they do not re-implement metrics.
- The offload decorator surfaces `summary`/`top_findings`/`compound_findings`
  into its `preview` (ADR-0001), so an offloaded report is **actionable inline**:
  the model narrates it from the summary without a second file read.

The extracted interpretation reference lives in
[`doc/INTERPRETATION_GUIDE.md`](../INTERPRETATION_GUIDE.md); `get_rw_git_documentation`
now leads with the meta-tools and points raw-tool users at that reference.

## Consequences

- **Positive**: a small/local model produces a complete, band-classified, ranked
  report from a **single** tool call. The `CHANGELOG` measurement on this repo: a
  technical report drops from ~9 hops / ~318K worst-case read-tokens to **1 hop /
  ~1.9K tokens, inline-complete**.
- **Positive**: classification thresholds and correlation rules are one
  deterministic, testable implementation rather than a prompt each model
  interprets differently — consistent, and aligned with the research-backed
  quality rule.
- **Positive**: the raw per-dimension tools remain available for capable models
  that want to drive the analysis themselves; the meta-tools are additive.
- **Negative / maintenance cost**: the thresholds and AND-rules now live in code
  and must be kept correct and justified. This is deliberate — it centralises the
  domain knowledge that was previously duplicated across prompts.
- **Negative**: a meta-tool does more work per call (it runs several analyses).
  This is offset by isolate offloading (ADR-0003) and by collapsing many
  model-driven hops into one.
