# 0012 — Structured logging facade and MCP log-level control

- **Status**: Accepted
- **Date**: 2026-07-02
- **Deciders**: rw_git maintainers
- **Related**: [ADR-0008](0008-rules-pattern-for-mcp-request-dispatch.md)

## Context

Library code (notably `GitCommand`) logged directly through `dart:developer`.
That surface is visible in DevTools and IDEs, but invisible to MCP hosts: a
host running `rw_git_mcp` over stdio has no way to see command timings or
failures, and no way to choose how verbose the server should be. The MCP
specification provides exactly this channel — a `logging` capability, a
`logging/setLevel` request, and `notifications/message` server notifications
using the RFC 5424 syslog severities.

Two constraints shaped the design:

- **Non-intrusive observability.** Existing `dart:developer` behaviour must
  not regress, and an MCP host that never opts in must not be flooded with
  per-command debug events over stdio.
- **Surgical wiring.** `GitCommand` instances are constructed in dozens of
  places; threading a logger through every constructor would churn the whole
  strategy hierarchy for a cross-cutting concern.

## Decision

- **A process-wide logging facade**, `RwGitLogger`
  (`lib/src/core/rw_git_logger.dart`), replaces direct `developer.log` calls
  in library code. Every event still flows to `dart:developer` (with a
  numeric level mapped from the MCP severity), so IDE observability is
  unchanged. The facade is a deliberate, documented exception to
  prefer-DI-over-singletons (`CODING_STANDARDS.md` §4.8): the swappable
  `listener` keeps it testable.
- **MCP severities as a typed enum.** `McpLogLevel` mirrors the RFC 5424
  levels in ascending severity order; filtering is an index comparison, and
  wire names are the enum names.
- **The MCP server subscribes as the listener.** `McpServer` forwards each
  event to the host as a `notifications/message` with `logger: "rw_git"`,
  gated by `McpRequestContext.minimumLogLevel`.
- **Hosts control verbosity via `logging/setLevel`**, handled by a new
  `LoggingSetLevelRule` (Rules pattern, ADR-0008). Unknown level names are
  rejected with JSON-RPC invalid-params rather than coerced. The server
  advertises the `logging` capability in `initialize`.
- **The default minimum level is `warning`.** Per-command start/finish
  events are logged at `debug`, failures at `error`; a host that never calls
  `logging/setLevel` therefore only receives failures and worse, keeping the
  stdio channel quiet by default.

## Consequences

- **Positive**: MCP hosts gain first-class, level-controlled visibility into
  git command execution without any change to library call sites beyond the
  facade swap.
- **Positive**: severity is now explicit at every call site (`debug` for
  routine lifecycle, `error` for failures) instead of implicit in a bare
  `developer.log`.
- **Negative / trade-off**: the facade is a process-wide singleton; if two
  `McpServer` instances existed in one process, the last one constructed
  would own the notification stream. The server binary only ever constructs
  one.
