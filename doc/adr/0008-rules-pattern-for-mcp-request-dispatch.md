# 0008 — Dispatch MCP JSON-RPC methods via the Rules design pattern

- **Status**: Accepted
- **Date**: 2026-07-01
- **Deciders**: rw_git maintainers
- **Governing documents**: [`CODING_STANDARDS.md`](../CODING_STANDARDS.md)

## Context

`McpServer._handleRequest` (`lib/src/mcp/mcp_server.dart`) is the single entry
point for every incoming JSON-RPC message (`initialize`, `ping`,
`resources/list`, `resources/read`, `prompts/list`, `prompts/get`,
`tools/list`, `tools/call`, `notifications/initialized`). It had grown into a
god method: one long `if`/`else if` chain that mixed routing (which method is
this?) with per-method business logic (param validation, registry lookups,
response shaping, error translation). Every new MCP method added another
branch and made the method longer and harder to test or reason about in
isolation. `CODING_STANDARDS.md`'s Open/Closed and Single Responsibility
guidance argues against this shape: adding behavior should not require
editing a shared, ever-growing conditional.

## Decision

Replace the `if`/`else if` chain with the
[Rules design pattern](https://www.michael-whelan.net/rules-design-pattern/):
a collection of small, independent objects, each responsible for one JSON-RPC
method, dispatched by a simple loop.

- **`McpRule` interface** (`lib/src/mcp/mcp_server/rules/mcp_rule.dart`):
  `bool matches(String? method)` plus
  `Future<void> handle(McpRequestContext ctx, dynamic id, Map<String, dynamic> params)`.
- **One rule class per method**, each in its own file under
  `lib/src/mcp/mcp_server/rules/` (e.g. `InitializeRule`, `PingRule`,
  `ToolsCallRule`, `ResourcesReadRule`), containing exactly the logic that
  previously lived in its `if`/`else if` branch.
- **`McpRequestContext`** (`lib/src/mcp/mcp_server/mcp_request_context.dart`):
  a shared collaborator bundling the `McpRegistry`, the output sink, and the
  JSON-RPC response helpers (`sendResponse`, `sendToolResult`, `sendError`,
  cursor encode/decode) that rules need but shouldn't each reimplement.
- **`McpServer` becomes a thin dispatcher**: it builds one `McpRequestContext`
  and an ordered `List<McpRule>` in its constructor, and `_handleRequest`
  reduces to iterating the list, calling `handle` on the first rule whose
  `matches` returns true, and falling back to a `-32601 Method not found`
  error if none match.

## Consequences

- **Positive**: adding a new MCP method means adding one new rule file and one
  line to the rules list — `McpServer` itself no longer changes, satisfying
  the Open/Closed Principle.
- **Positive**: each rule is independently readable and testable in isolation
  from the JSON-RPC transport plumbing (though existing tests continue to
  exercise the server as a black box over stdin/stdout, which was sufficient
  to verify this refactor preserved behavior).
- **Positive**: routing (`matches`) is now clearly separated from business
  logic (`handle`), and shared response-formatting concerns live in one place
  (`McpRequestContext`) instead of being duplicated as private methods on
  `McpServer`.
- **Negative**: more files/indirection for a small number of methods — reading
  the full dispatch behavior now means opening the rules directory rather
  than one method. Accepted as a reasonable tradeoff once the number of
  branches (9) made the single-method version genuinely hard to scan.
- **Constraint**: rule order matters only in the degenerate case of two rules
  matching the same method, which should never happen; the rules list is
  built once per `McpServer` in the order the original `if`/`else if` chain
  used, to keep behavior unambiguous.
