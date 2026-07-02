# 0013 — Structured tool results and the outputSchema advertisement policy

- **Status**: Accepted
- **Date**: 2026-07-02
- **Deciders**: rw_git maintainers
- **Related**: [ADR-0002](0002-mcp-tool-metadata-decorator.md) (the metadata
  decorator that carries `outputSchema`),
  [ADR-0007](0007-tools-list-token-budget-and-pagination.md) (the fixed
  `tools/list` token budget this policy protects),
  [ADR-0001](0001-file-offloading-of-large-tool-outputs.md) (the offload
  `preview` that conveys structure at response time)

## Context

Commit `66941fd` stamped a bespoke `outputSchema` onto nearly every tool.
Measurement showed two problems:

1. **A fixed token tax without a payoff.** The schemas added ~8–10 KB
   (~2,000+ tokens) to the serialized `tools/list` payload — the cost every
   conversation pays up-front, and which most local runtimes re-pay per
   request. Most of those schemas were broad but shallow: they enumerated
   top-level keys but declared leaf collections as bare `array`/`object`,
   information the offload summary's `preview` already delivers at response
   time for free, and only for the tools actually called.
2. **A spec promise the server never kept.** MCP 2025-06-18 specifies that a
   tool declaring an `outputSchema` should return `structuredContent`; the
   server only ever returned the stringified JSON inside a text content
   block, so the advertised schemas described a payload that was never
   delivered structurally.

## Decision

- **Advertise `outputSchema` only where the shape is stable, compact, and
  the structured payload is the product itself**: the five report meta-tools
  (`report_type`/`summary`/`top_findings`/`compound_findings` — the
  classified-findings contract), the tiny git-operation results
  (`_successOutputSchema`, `fetch_tags`), and the fixed-shape tools
  `get_stats`, `is_git_repository`, and
  `calculate_universal_lexical_metrics`. All other analysis tools advertise
  no schema; their structure reaches the model through the offload
  `preview`'s `structure` map at zero fixed cost.
- **Emit `structuredContent`.** `ToolsCallRule` decodes the tool's JSON
  string once for schema-declaring tools and attaches it as
  `structuredContent` alongside the standard text block (kept for backward
  compatibility, as the spec recommends). Non-JSON or non-object payloads
  fall back to text-only.
- **Offload summaries still validate.** When a schema-declaring report tool
  offloads, the returned summary (`status`/`file`/`preview`/…) differs from
  the advertised report shape. This is deliberate: the advertised schemas
  declare no `required` properties and leave `additionalProperties`
  unconstrained, so the summary — whose `preview` carries the same
  `summary`/`top_findings`/`compound_findings` keys — remains valid, and the
  schema keeps documenting the offloaded file's shape.
- The `tools/list` byte budget (`test/mcp/tools_list_size_test.dart`)
  guards the policy: adding a schema back to a broad-shape tool will trip
  the budget, and `test/mcp/tools_list_metadata_test.dart` pins which tools
  do and do not advertise one.

## Consequences

- **Positive**: the fixed `tools/list` cost dropped from ~41,000 to ~35,635
  bytes (~11,500 → ~9,900 tokens) while the remaining schemas gained real
  machine-readable value — every schema-declaring tool now actually returns
  `structuredContent` per MCP 2025-06-18.
- **Positive**: structure discovery scales with use — a model pays for a
  tool's shape only when it calls that tool (via the response `preview`),
  not up-front for all 37 tools.
- **Negative / trade-off**: models can no longer anticipate a non-schema
  tool's exact field names before the first call. Accepted: the report
  meta-tools (the primary small-model path) keep their schema, and the
  first response's `preview` closes the gap immediately.
