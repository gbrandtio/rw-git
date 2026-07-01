# 0009 — Order the tool registry for small-LLM discoverability (report tools first)

- **Status**: Accepted
- **Date**: 2026-07-02
- **Deciders**: rw_git maintainers
- **Related**: [ADR-0005](0005-server-side-interpretation-and-report-meta-tools.md),
  [ADR-0007](0007-tools-list-token-budget-and-pagination.md)

## Context

The order in which tools appear in the `tools/list` response is the order in
which they are registered in `buildDefaultRegistry`
(`lib/src/mcp/server_registry.dart`). Small and local models — the audience the
*Small and local models Competitive Advantage* rule prioritises — are strongly
position-biased: they disproportionately select tools that appear early in the
listing, and with `toolsPageSize` pagination (ADR-0007) a tiny-context client
may only ever see the first page.

ADR-0007 mentioned registering the report meta-tools first as one of its
mitigations, but the ordering itself was never recorded as a decision, so
nothing stops a refactor from silently reordering the registry (e.g.
alphabetically) and degrading small-model behavior without any test failing.

## Decision

Registration order in `buildDefaultRegistry` is a **deliberate, load-bearing
ranking**, not an artifact of code layout:

1. **Report meta-tools first** (ADR-0005): `generate_repository_audit`,
   `generate_technical_report`, `generate_security_report`,
   `generate_pm_report`, `generate_code_review_report`. They are the intended
   one-call entry point for small models and must occupy the top of the
   listing (and the first page when pagination is enabled).
2. **Raw analysis and discovery tools next**, with frequently useful tools
   (`analyze_code_quality`, `get_rw_git_documentation`, `read_report_slice`)
   ahead of niche ones.
3. **Mutating repository operations** (clone, checkout, init, fetch) carry
   `readOnlyHint: false` and are interleaved only where workflow requires;
   they must never displace the report tools from the top.

Contributors adding a tool must insert it by intent (where should a model find
it?) rather than appending by habit, and a comment in `server_registry.dart`
records the report-tools-first rule at the registration site.

## Consequences

- **Positive**: the prominent-choice nudge that ADR-0005/0007 rely on is now a
  recorded decision; reordering the registry is a reviewable architecture
  change, not an invisible refactor side-effect.
- **Positive**: paginated tiny-context clients get the highest-leverage tools
  on the first page by construction.
- **Negative / trade-off**: registration order and import order in
  `server_registry.dart` no longer match a mechanical convention
  (e.g. alphabetical), which mildly surprises contributors used to sorted
  registries. The registration-site comment mitigates this.
