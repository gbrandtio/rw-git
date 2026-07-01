# 0003 — Offload CPU-bound parsing to background Isolates

- **Status**: Accepted
- **Date**: 2026-07-01
- **Deciders**: rw_git maintainers
- **Governing document**: [`DART_PERFORMANCE_AND_CONCURRENCY.md`](../DART_PERFORMANCE_AND_CONCURRENCY.md)

## Context

> **Terminology.** This ADR is about **compute offloading** — moving CPU-bound
> work off the main event loop onto a worker thread. It is unrelated to the
> **file offloading** of large tool *results* to disk in
> [ADR-0001](0001-file-offloading-of-large-tool-outputs.md), which happens to
> share the word "offload". Keeping the two straight matters when reading the
> code, where both meanings appear.

Dart runs the main isolate single-threaded on an event loop. `rw_git`'s value
comes from parsing large `git` outputs — logs, diffs, blame, status — and running
regex-heavy heuristics and analysis algorithms over them. On a real repository
these inputs are megabytes of text. Doing that work synchronously on the main
isolate would block the event loop: the MCP server could not read the next
JSON-RPC line, and an embedding application would stall.

`AGENTS.md` → *Project Guardrails* codifies the limit: **if a parsing task
blocks the main isolate for more than 16 ms under high load, it must be offloaded
to a background Isolate.**

## Decision

Run the heavy, CPU-bound parsing and analysis in short-lived background isolates
via **`Isolate.run(...)`** (Dart's preferred pure-Dart primitive over Flutter's
`compute`). The pattern is applied consistently:

- **Command parsers** (`diff_command`, `blame_command`, `status_command`,
  `get_commits_command`, …) offload their `RwGitParser.parse*` step.
- **Intelligence heuristics and algorithms** (secrets scanner, compliance
  scanner, dependency-manifest parser, refactoring detection, bus factor,
  logical coupling, code volatility, commit velocity, advanced metrics,
  mega/suspicious-commit heuristics) offload their parse/scan step.
- **Composite MCP tools** (Dart AST quality, file ownership, PR diff, release
  delta, changelog) offload their aggregation step.

The isolate entry point is always a **top-level or static, stateless** function
(e.g. `_parseSecrets`, `_parseRefactorings`) that takes the raw string and
returns the parsed result, satisfying the "stateless workers" rule — an isolate
cannot see the main heap and communicates only by copied messages.

I/O (running the `git` process) stays on the main isolate, since it is
event-loop-friendly and not CPU-bound; only the subsequent *parsing* of its
output is offloaded.

## Consequences

- **Positive**: the MCP server's event loop stays responsive during large
  analyses; it can keep servicing the JSON-RPC read loop while a heavy parse runs
  on a worker thread.
- **Positive**: embedding applications that use `rw_git` as a library do not
  experience main-thread stalls from the package's parsing.
- **Positive**: the entry points are pure functions of `(rawOutput) → result`,
  which also makes the parsing logic trivially unit-testable (`CODING_STANDARDS.md`
  §2 — pure functions).
- **Negative / trade-off**: crossing the isolate boundary copies the input and
  the result. Per `DART_PERFORMANCE_AND_CONCURRENCY.md`, this is only a win when
  the compute saved outweighs the copy cost; for these megabyte-scale, regex-heavy
  parses it clearly does, but it means the pattern should **not** be applied
  reflexively to trivial transforms.
- **Negative**: `Isolate.run` spins up and tears down a worker per call. For the
  request/response shape of MCP tools this is fine; a hypothetical continuous
  streaming workload would instead warrant a long-lived isolate with explicit
  ports (also noted in the governing document).
