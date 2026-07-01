# 0002 — MCP tool metadata via an outermost decorator

- **Status**: Accepted
- **Date**: 2026-07-01
- **Deciders**: rw_git maintainers
- **Related**: [ADR-0001](0001-file-offloading-of-large-tool-outputs.md),
  [ADR-0007](0007-tools-list-token-budget-and-pagination.md)

## Context

The MCP specification lets a `tools/list` entry carry optional metadata beyond
name / description / input schema:

- **`annotations`** — behavioural hints such as `readOnlyHint` and
  `idempotentHint`, which let a client auto-approve safe, repeatable analysis
  tools and withhold auto-approval from state-mutating ones (clone, checkout,
  init, fetch).
- **`outputSchema`** — a JSON Schema describing the tool's structured output, so
  a model knows the shape of a result (or of an offloaded file, ADR-0001)
  *before* calling and without reading anything.

Advertising these is directly aligned with the *Small and local models
Competitive Advantage* rule: a small model that knows a tool is read-only and
knows its output shape can plan correctly in one shot.

The problem is *where* to put this metadata. Two rejected options:

1. **Add `annotations` / `outputSchema` getters to the `McpTool` interface.**
   This violates the Interface Segregation Principle (`CODING_STANDARDS.md` §3):
   every tool would be forced to define metadata it does not use, and most tools
   have nothing meaningful to say.
2. **Hard-code the metadata inside each concrete tool.** This scatters a
   cross-cutting concern across ~30 classes, couples each tool to MCP wire
   details, and makes the read-only/mutating policy impossible to see in one
   place.

## Decision

Model tool metadata as an **optional, opt-in mixin** and attach it with an
**outermost decorator**:

- `McpToolMetadata` is a mixin on the `McpTool` contract exposing nullable
  `annotations` and `outputSchema` getters that default to `null`. Tools that
  say nothing are unaffected — Interface Segregation is preserved.
- `McpToolWithMetadata` is a decorator that wraps any `McpTool`, holds the
  `annotations` / `outputSchema` values, and delegates `name`, `description`,
  `inputSchema`, and `execute` to the inner tool unchanged.
- Metadata is applied **at registration time** in `server_registry.dart`, where
  the policy is centralised as three shared constants — `_readOnly`
  (`readOnlyHint + idempotentHint`), `_mutating` (`readOnlyHint: false`), and the
  compact `_reportOutputSchema` shared by the report meta-tools (ADR-0005).

Because it is the **outermost** wrapper, the registry sees the metadata while
name/description/input-schema/execute still resolve through the inner stack
(typically the file-offload decorator, ADR-0001, then the concrete tool). The
metadata layer is therefore purely additive and never alters behaviour.

## Architecture

### Composition and registration

```
registry.registerTool(
  McpToolWithMetadata(                       // outermost: metadata only
    McpToolFileOffloadDecorator(             // ADR-0001: disk offload
      <concrete analysis tool>,              // produces raw JSON
      resources: registry.resources),
    annotations: _readOnly,
    outputSchema: _reportOutputSchema))
```

Two registration helpers in `server_registry.dart` encode the policy so it
cannot drift:

- `ro(tool, {outputSchema})` — wraps with `McpToolWithMetadata(annotations:
  _readOnly, …)`.
- `offloadedRo(inner, {outputSchema})` — composes the offload decorator **then**
  `ro`, i.e. the standard read-only-analysis wiring.
- `mutating(tool)` — wraps with `annotations: _mutating` and no offload (these
  tools return small status payloads and change state).

### Why outermost

Placing the metadata wrapper outside the offload decorator keeps
responsibilities cleanly separated (Single Responsibility, `CODING_STANDARDS.md`
§3): the offload decorator owns the *runtime* behaviour (size-gating, writing
files, previews); the metadata decorator owns only the *advertised* `tools/list`
surface. Neither knows about the other's concern. Reordering them would force the
offload decorator to also forward metadata, re-coupling the two.

## Consequences

- **Positive**: the read-only vs mutating policy and the shared report output
  schema live in one file and read like a table, making the safety posture of the
  whole tool surface auditable at a glance.
- **Positive**: tools opt in to metadata by being wrapped, not by implementing
  an interface — no tool is forced to carry metadata it does not have.
- **Positive**: standards-aware clients get `readOnlyHint`/`idempotentHint` for
  auto-approval and `outputSchema` for one-shot planning, advancing the
  small-model efficiency goal.
- **Negative**: metadata is a wrapper, so a tool obtained directly (bypassing
  the registry) exposes no metadata. This is acceptable: the registry is the
  single source of truth for the served surface.
- **Trade-off**: `outputSchema` is deliberately kept compact (the report schema
  lists only the four top-level fields) to respect the `tools/list` token budget
  (ADR-0007) rather than fully describing every nested shape.
